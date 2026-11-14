"""Data sources: Open-Meteo (free, no key) and Meteocat (key + monthly quota).

Every fetch goes through the store: fresh cache → network → stale cache. Meteocat calls also pass the
quota governor, which spreads each plan's monthly budget over the remaining days.
"""
import calendar
import hashlib
from urllib.parse import parse_qsl
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
          'pressure_msl,cloud_cover,visibility,dew_point_2m')
DAILY = ('sunrise,sunset,temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code,'
         'precipitation_sum,uv_index_max,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant')
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
        return self._get(f'om:fc2:{lat:.3f},{lon:.3f}:{days}', OM_FORECAST, p, 3600)  # fc2: + visibility, dew point, daily totals

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

    def places(self, q: str):
        p = dict(name=q, count=20, language='en', countryCode='ES')
        return self._get(f'om:geo:{q.lower()}', 'https://geocoding-api.open-meteo.com/v1/search', p, 30 * 86400)

    def reverse(self, lat: float, lon: float):
        # Nominatim: 1 req/s policy; results are cached for 30 days at ~1 km resolution.
        # ~100 m resolution: coarser rounding can land a coastal point in the sea (→ only a country name).
        p = dict(lat=f'{lat:.3f}', lon=f'{lon:.3f}', format='jsonv2', zoom=12)
        return self._get(f'osm:rev:{lat:.3f},{lon:.3f}', 'https://nominatim.openstreetmap.org/reverse', p, 30 * 86400)

    def grid_forecast(self, lats: list[float], lons: list[float], hours: int = 48):
        p = dict(latitude=','.join(f'{x:.2f}' for x in lats), longitude=','.join(f'{x:.2f}' for x in lons),
                 hourly='wind_speed_10m,wind_direction_10m,wind_gusts_10m,temperature_2m,precipitation,'
                        'precipitation_probability,weather_code,cape',
                 forecast_hours=hours, wind_speed_unit='kn', timezone=settings.tz)
        return self._get(f'om:gridfc2:{len(lats)}:{hours}', OM_FORECAST, p, 3600)  # 2: + CAPE for the thunder layer

    def reverse_nearest(self, lat: float, lon: float):
        """Photon (OSM data): nearest named features, works for points just offshore."""
        p = dict(lat=f'{lat:.3f}', lon=f'{lon:.3f}', limit=5)
        return self._get(f'photon:rev:{lat:.3f},{lon:.3f}', 'https://photon.komoot.io/reverse', p, 30 * 86400)

    def elevation(self, lats: list[float], lons: list[float]):
        """Terrain elevation (m) for up to 100 points (Copernicus DEM; 0 over the sea)."""
        p = dict(latitude=','.join(f'{x:.4f}' for x in lats), longitude=','.join(f'{x:.4f}' for x in lons))
        key = 'om:elev:' + hashlib.md5((p['latitude'] + p['longitude']).encode()).hexdigest()[:16]
        return self._get(key, 'https://api.open-meteo.com/v1/elevation', p, 365 * 86400)

    def route_forecast(self, lats: list[float], lons: list[float]):
        """Hourly forecast for up to 60 points along a route (7 days)."""
        p = dict(latitude=','.join(f'{x:.3f}' for x in lats), longitude=','.join(f'{x:.3f}' for x in lons),
                 hourly='temperature_2m,apparent_temperature,precipitation,precipitation_probability,weather_code,'
                        'wind_speed_10m,wind_direction_10m,wind_gusts_10m,cape,is_day',
                 forecast_days=7, wind_speed_unit='kn', timezone=settings.tz)
        key = 'om:route:' + hashlib.md5((p['latitude'] + p['longitude']).encode()).hexdigest()[:16]
        return self._get(key, OM_FORECAST, p, 3600)

    def grid(self, lats: list[float], lons: list[float]):
        p = dict(latitude=','.join(f'{x:.2f}' for x in lats), longitude=','.join(f'{x:.2f}' for x in lons),
                 current='wind_speed_10m,wind_direction_10m,wind_gusts_10m,temperature_2m,precipitation',
                 wind_speed_unit='kn', timezone=settings.tz)
        return self._get(f'om:grid:{len(lats)}', OM_FORECAST, p, 1800)

    # ── Meteocat (only with a key; every call is budgeted) ──
    def meteocat_available(self) -> bool:
        return bool(settings.meteocat_key)

    @staticmethod
    def _today_plan(plan: str) -> str:
        return f'{plan}@{datetime.now(timezone.utc):%Y-%m-%d}'  # daily ledger row next to the monthly one

    def allowance(self, plan: str) -> int:
        """Calls still allowed today: today's fair share of what was left this morning, minus today's calls."""
        now = datetime.now(timezone.utc)
        days_left = calendar.monthrange(now.year, now.month)[1] - now.day + 1
        today = self.store.used(self._today_plan(plan))
        left_at_start = settings.quota[plan] - self.store.used(plan) + today
        share = -(-max(0, left_at_start) // days_left)  # ceil
        return max(0, min(share - today, settings.quota[plan] - self.store.used(plan)))

    def sync_quota(self) -> dict:
        """Align the ledger with Meteocat's counter (/quotes/v1/consum-actual), which also sees calls made elsewhere."""
        names = {'predicci': 'prediccio', 'xema': 'xema', 'xdde': 'xdde', 'refer': 'referencia', 'quota': 'quotes'}
        data = self.meteocat('quotes', '/quotes/v1/consum-actual', 0)
        out = {}
        for p in data.get('plans', []):
            plan = next((v for k, v in names.items() if p['nom'].lower().startswith(k)), None)
            if plan:
                self.store.set_used(plan, max(self.store.used(plan), int(p['consultesRealitzades'])))
                out[plan] = (int(p['consultesRealitzades']), int(p['maxConsultes']))
        return out

    def meteocat(self, plan: str, path: str, max_age: float):
        key = f'mc:{path}'
        hit = self.store.get(key, max_age)
        if hit is not None:
            return hit
        if not settings.meteocat_key:
            raise QuotaExceeded('no Meteocat key')
        if self.allowance(plan) <= 0:  # today's share is used up: last known answer, or nothing
            stale = self.store.stale(key)
            if stale is not None:
                return stale
            raise QuotaExceeded(plan)
        self.store.spend(plan)
        self.store.spend(self._today_plan(plan))
        # httpx replaces a URL's own query with `params`, so the query has to travel as params.
        url, _, query = path.partition('?')
        return self._get(key, METEOCAT + url, dict(parse_qsl(query)), 0, headers={'X-Api-Key': settings.meteocat_key})

    def try_meteocat(self, plan: str, path: str, max_age: float):
        try:
            return self.meteocat(plan, path, max_age)
        except Exception as e:
            log.info('meteocat %s unavailable: %s', path, e)
            return None
