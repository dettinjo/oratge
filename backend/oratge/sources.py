"""Data sources: Open-Meteo (free, no key) and Meteocat (key + monthly quota).

Every fetch goes through the store: fresh cache → network → stale cache. Meteocat calls also pass the
quota governor, which spreads each plan's monthly budget over the remaining days.
"""
import calendar
import logging
from datetime import datetime, timezone

import httpx

from .config import settings
from .store import Store

log = logging.getLogger('oratge')

OM_FORECAST = 'https://api.open-meteo.com/v1/forecast'
OM_MARINE = 'https://marine-api.open-meteo.com/v1/marine'
OM_ENSEMBLE = 'https://ensemble-api.open-meteo.com/v1/ensemble'
METEOCAT = 'https://api.meteo.cat'

HOURLY = ('temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,precipitation_probability,'
          'weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,uv_index,cape,freezing_level_height,'
          'pressure_msl,cloud_cover')
DAILY = 'sunrise,sunset,temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code'
WEATHER_MODELS = {'meteofrance_arome_france_hd': ('AROME', '1.3 km · Météo-France'),
                  'meteofrance_arpege_europe': ('ARPEGE', '10 km · Météo-France'),
                  'icon_eu': ('ICON-EU', '7 km · DWD'), 'ecmwf_ifs025': ('ECMWF IFS', '9 km'),
                  'gfs_seamless': ('GFS', '13 km · NOAA')}
WAVE_MODELS = {'meteofrance_wave': ('MFWAM', 'Météo-France waves'), 'dwd_ewam': ('DWD EWAM', '5 km · DWD'),
               'ecmwf_wam025': ('ECMWF WAM', '9 km'), 'ncep_gfswave025': ('GFS WaveWatch III', '25 km · NOAA')}


class QuotaExceeded(Exception):
    pass


class Sources:
    def __init__(self, store: Store, client: httpx.Client | None = None):
        self.store = store
        self.http = client or httpx.Client(timeout=20, headers={'User-Agent': 'oratge/0.1 (homelab)'})

    def _get(self, key: str, url: str, params: dict, max_age: float, headers: dict | None = None):
        hit = self.store.get(key, max_age)
        if hit is not None:
            return hit
        try:
            r = self.http.get(url, params=params, headers=headers or {})
            r.raise_for_status()
            body = r.json()
            self.store.put(key, body)
            return body
        except Exception as e:  # network or API error → serve the last good copy
            log.warning('fetch failed %s: %s', key, e)
            stale = self.store.stale(key)
            if stale is None:
                raise
            return stale

    # ── Open-Meteo ──
    def forecast(self, lat: float, lon: float, days: int = 8):
        p = dict(latitude=lat, longitude=lon, hourly=HOURLY, daily=DAILY, forecast_days=days, past_days=1,
                 wind_speed_unit='kn', timezone=settings.tz)
        return self._get(f'om:fc:{lat:.3f},{lon:.3f}:{days}', OM_FORECAST, p, 3600)

    def models(self, lat: float, lon: float, variable: str):
        p = dict(latitude=lat, longitude=lon, hourly=variable, forecast_days=3, wind_speed_unit='kn',
                 timezone=settings.tz, models=','.join(WEATHER_MODELS))
        return self._get(f'om:mm:{lat:.3f},{lon:.3f}:{variable}', OM_FORECAST, p, 3 * 3600)

    def marine(self, lat: float, lon: float):
        p = dict(latitude=lat, longitude=lon, forecast_days=8, timezone=settings.tz,
                 hourly='wave_height,wave_direction,wave_period,swell_wave_height,swell_wave_direction,'
                        'swell_wave_period,sea_surface_temperature')
        return self._get(f'om:mar:{lat:.3f},{lon:.3f}', OM_MARINE, p, 3 * 3600)

    def marine_models(self, lat: float, lon: float):
        p = dict(latitude=lat, longitude=lon, forecast_days=3, timezone=settings.tz, hourly='wave_height',
                 models=','.join(WAVE_MODELS))
        return self._get(f'om:marm:{lat:.3f},{lon:.3f}', OM_MARINE, p, 6 * 3600)

    def ensemble(self, lat: float, lon: float, variable: str):
        p = dict(latitude=lat, longitude=lon, hourly=variable, forecast_days=3, wind_speed_unit='kn',
                 timezone=settings.tz, models='ecmwf_ifs025')
        return self._get(f'om:ens:{lat:.3f},{lon:.3f}:{variable}', OM_ENSEMBLE, p, 6 * 3600)

    # ── Meteocat (only with a key; every call is budgeted) ──
    def meteocat_available(self) -> bool:
        return bool(settings.meteocat_key)

    def allowance(self, plan: str) -> int:
        """Calls still allowed today so the plan's monthly budget lasts to the end of the month."""
        now = datetime.now(timezone.utc)
        days_left = calendar.monthrange(now.year, now.month)[1] - now.day + 1
        left = settings.quota[plan] - self.store.used(plan)
        return max(0, left // days_left + (1 if left % days_left else 0))

    def meteocat(self, plan: str, path: str, max_age: float):
        key = f'mc:{path}'
        hit = self.store.get(key, max_age)
        if hit is not None:
            return hit
        if not settings.meteocat_key:
            raise QuotaExceeded('no Meteocat key')
        if settings.quota[plan] - self.store.used(plan) <= 0:
            stale = self.store.stale(key)
            if stale is not None:
                return stale
            raise QuotaExceeded(plan)
        self.store.spend(plan)
        return self._get(key, METEOCAT + path, {}, 0, headers={'X-Api-Key': settings.meteocat_key})

    def try_meteocat(self, plan: str, path: str, max_age: float):
        try:
            return self.meteocat(plan, path, max_age)
        except Exception as e:
            log.info('meteocat %s unavailable: %s', path, e)
            return None
