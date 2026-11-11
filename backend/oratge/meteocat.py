"""Meteocat products beyond warnings: station network lookup, live readings anywhere, lightning,
beach and summit forecasts. Formats checked against live responses on 2026-11-11.

Quota (monthly): XEMA 750, Predicció 100, XDDE 250. Every call goes through the governor in
Sources.meteocat (daily share + stale cache). Forecast products (beach, summit) only run while at
least one Predicció call stays in today's budget for the warnings.
"""
from __future__ import annotations

import logging
import math
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from .config import settings

log = logging.getLogger('oratge')
TZ = ZoneInfo(settings.tz)
MS_TO_KN = 1.94384
KMH_TO_KN = 0.539957

# XEMA variable codes (subset we read).
WIND, WDIR, TEMP, RH, PRESSURE, RAIN, SOLAR, SNOW, UV, GUST = 30, 31, 32, 33, 34, 35, 36, 38, 39, 50


def km(lat1, lon1, lat2, lon2) -> float:
    p = math.pi / 180
    a = (math.sin((lat2 - lat1) * p / 2) ** 2
         + math.cos(lat1 * p) * math.cos(lat2 * p) * math.sin((lon2 - lon1) * p / 2) ** 2)
    return 12742 * math.asin(math.sqrt(a))


class Meteocat:
    def __init__(self, src):
        self.src = src

    @property
    def available(self) -> bool:
        return self.src.meteocat_available()

    # ── station network ──
    def stations(self) -> list[dict]:
        """Operational XEMA stations (code, name, coords, altitude, comarca). One call a month."""
        first = date.today().replace(day=1)
        data = self.src.try_meteocat('xema', f'/xema/v1/estacions/metadades?estat=ope&data={first:%Y-%m-%d}Z', 40 * 86400)
        out = []
        for s in data or []:
            try:
                out.append({'code': s['codi'], 'name': s['nom'], 'lat': s['coordenades']['latitud'],
                            'lon': s['coordenades']['longitud'], 'alt': s.get('altitud'),
                            'comarca': (s.get('comarca') or {}).get('codi'), 'comarca_name': (s.get('comarca') or {}).get('nom'),
                            'municipi': (s.get('municipi') or {}).get('nom')})
            except (KeyError, TypeError):
                continue
        return out

    def wind_codes(self) -> set[str]:
        """Stations with an anemometer (latest wind reading for all stations: one call, kept a month)."""
        data = self.src.try_meteocat('xema', '/xema/v1/variables/mesurades/30/ultimes', 30 * 86400)
        return {s['codi'] for s in data or [] if isinstance(s, dict) and 'codi' in s}

    def nearest(self, lat: float, lon: float, wind: bool = False, max_km: float = 30) -> dict | None:
        sts = self.stations()
        if wind:
            codes = self.wind_codes()
            sts = [s for s in sts if s['code'] in codes]
        best = min(sts, key=lambda s: km(lat, lon, s['lat'], s['lon']), default=None)
        if best is None:
            return None
        d = km(lat, lon, best['lat'], best['lon'])
        return {**best, 'km': round(d, 1)} if d <= max_km else None

    def comarca(self, lat: float, lon: float) -> tuple[int, str] | None:
        """Comarca of the closest station: good enough to match warnings (issued per comarca)."""
        s = self.nearest(lat, lon, max_km=20)
        return (s['comarca'], s['comarca_name']) if s and s.get('comarca') else None

    # ── readings ──
    def readings(self, code: str, day: date | None = None, max_age: float = 1800) -> dict[int, list]:
        day = day or datetime.now(timezone.utc).date()  # XEMA days are UTC
        data = self.src.try_meteocat('xema', f'/xema/v1/estacions/mesurades/{code}/{day:%Y/%m/%d}', max_age)
        try:
            return {v['codi']: v['lectures'] for v in data[0]['variables']} if data else {}
        except (KeyError, IndexError, TypeError):
            return {}

    def live(self, lat: float, lon: float, station: str | None = None, wind_station: str | None = None) -> dict | None:
        """Latest readings near a point. Wind comes from the closest station that measures it.

        Extras from the same response (no extra calls): rain last 3 h and since midnight UTC, humidity,
        pressure with its 3-hour trend, UV, solar radiation and snow depth where measured."""
        if not self.available:
            return None
        st = {'code': station} if station else self.nearest(lat, lon)
        if not st:
            return None
        v = self.readings(st['code'])
        if not v:
            return None
        wind_from = st
        if WIND not in v:
            ws = {'code': wind_station} if wind_station else self.nearest(lat, lon, wind=True)
            if ws and ws['code'] != st['code']:
                wv = self.readings(ws['code'])
                v = {**v, **{c: wv[c] for c in (WIND, WDIR, GUST) if c in wv}}
                wind_from = ws

        def last(c):
            return float(v[c][-1]['valor']) if v.get(c) else None

        def total(c, n=None):
            vals = [float(x['valor']) for x in (v.get(c) or [])]
            return round(sum(vals[-n:] if n else vals), 1) if vals else None

        ts = (v.get(TEMP) or v.get(WIND) or [{}])[-1].get('data')
        if not ts:
            return None
        at = datetime.fromisoformat(ts.replace('Z', '+00:00'))
        age = max(0, int((datetime.now(timezone.utc) - at).total_seconds() // 60))
        p = v.get(PRESSURE) or []
        trend = round(float(p[-1]['valor']) - float(p[-7]['valor']), 1) if len(p) >= 7 else None
        kn = lambda x: None if x is None else round(x * MS_TO_KN, 1)  # noqa: E731
        names = {s['code']: s for s in self.stations()}
        return {
            'station': st['code'], 'station_name': (names.get(st['code']) or st).get('name', st['code']),
            'station_km': st.get('km'), 'wind_station_name': (names.get(wind_from['code']) or wind_from).get('name')
            if wind_from is not st else None,
            'age_min': age, 'age': f'{age} min ago', 'at': at.astimezone(TZ).strftime('%H:%M'),
            'temp': last(TEMP), 'wind': kn(last(WIND)), 'gust': kn(last(GUST)), 'wdir': last(WDIR),
            'humidity': last(RH), 'pressure': last(PRESSURE), 'pressure_trend': trend,
            'rain_3h': total(RAIN, 6), 'rain_today': total(RAIN), 'uv': last(UV), 'solar': last(SOLAR), 'snow': last(SNOW),
        }

    # ── lightning (XDDE) ──
    def lightning(self, lat: float, lon: float, radius: float = 30) -> dict | None:
        """Strikes within [radius] km in the current and previous UTC hour (2 calls, current hour cached 20 min).

        Strike fields are parsed defensively (no strikes on the day the format was checked):
        coordinates under 'coordenades' {latitud, longitud} or top-level lat/lon, time under 'data'."""
        if not self.available:
            return None
        now = datetime.now(timezone.utc)
        strikes = []
        for h, age in ((now - timedelta(hours=1), 7 * 86400), (now, 1200)):
            data = self.src.try_meteocat('xdde', f'/xdde/v1/catalunya/{h:%Y/%m/%d/%H}', age)
            if data is None:
                return None  # budget or network: say nothing rather than "no lightning"
            for s in data if isinstance(data, list) else []:
                try:
                    c = s.get('coordenades') or s
                    la, lo = float(c.get('latitud', c.get('lat'))), float(c.get('longitud', c.get('lon')))
                    d = km(lat, lon, la, lo)
                    if d <= radius:
                        strikes.append((d, s.get('data', ''), bool(s.get('nuvolTerra', True))))
                except (TypeError, ValueError, AttributeError):
                    continue
        if not strikes:
            return {'count': 0, 'near': 0, 'nearest_km': None, 'last': None, 'radius': radius}
        last = max(t for _, t, _ in strikes)
        try:
            last = datetime.fromisoformat(last.replace('Z', '+00:00')).astimezone(TZ).strftime('%H:%M')
        except ValueError:
            pass
        return {'count': len(strikes), 'near': sum(1 for d, _, _ in strikes if d <= 10),
                'nearest_km': round(min(d for d, _, _ in strikes), 1), 'last': last, 'radius': radius}

    # ── forecasts (Predicció; scarce) ──
    def _forecast_ok(self) -> bool:
        return self.available and self.src.allowance('prediccio') > 1  # keep one call for the warnings

    def beach(self, slug: str, day: date | None = None) -> list[dict]:
        """Hourly beach forecast: air temp, humidity, wind, sky, waves, water temperature, UV. One call per beach-day."""
        day = day or date.today()
        path = f'/pronostic/v1/platges/{slug}/{day:%Y/%m/%d}'
        key_ok = self.src.store.get(f'mc:{path}', 86400) is not None
        if not key_ok and not self._forecast_ok():
            data = self.src.store.stale(f'mc:{path}')
        else:
            data = self.src.try_meteocat('prediccio', path, 86400)
        out = []
        for h in (data or {}).get('prediccionsHora', []):
            try:
                v = h['variables']
                f = lambda k: float(v[k]['valor']) if k in v and v[k].get('valor') not in (None, '') else None  # noqa: E731
                t = datetime.fromisoformat(h['data'].replace('Z', '+00:00')).astimezone(TZ)
                out.append({'t': t.strftime('%Y-%m-%dT%H:00'), 'hour': t.hour, 'temp': f('temperatura'),
                            'humidity': f('humitatRelativa'), 'wind': None if f('velVent') is None else round(f('velVent') * MS_TO_KN, 1),
                            'wdir': f('dirVent'), 'sky': f('estatCel'), 'wave': f('alturaOna'), 'wave_dir': f('direccioOna'),
                            'sst': f('temperaturaAigua'), 'uv': f('uviPrevist')})
            except (KeyError, ValueError, TypeError):
                continue
        return out

    def summit(self, slug: str, day: date | None = None) -> list[dict]:
        """3-hourly summit forecast per altitude band (temp, humidity, wind) plus freezing level."""
        day = day or date.today()
        path = f'/pronostic/v1/pirineu/pics/{slug}/{day:%Y/%m/%d}'
        if self.src.store.get(f'mc:{path}', 86400) is None and not self._forecast_ok():
            data = self.src.store.stale(f'mc:{path}')
        else:
            data = self.src.try_meteocat('prediccio', path, 86400)
        out = []
        for step in data or []:
            try:
                t = datetime.fromisoformat(step['data'].replace('Z', '+00:00')).astimezone(TZ)
                row = {'t': t.strftime('%Y-%m-%dT%H:00'), 'hour': t.hour, 'levels': {}}
                for cota in step.get('cotes', []):
                    vals = {x['nom']: x['valor'] for x in cota.get('variables', [])}
                    if cota.get('cota') == 'totes':
                        row['freezing'] = vals.get('isozero')
                        row['iso10'] = vals.get('iso-10')
                    else:
                        row['levels'][int(cota['cota'])] = {
                            'temp': vals.get('temperatura'), 'humidity': vals.get('humitat'), 'wdir': vals.get('direccio vent'),
                            # Summit wind is published in km/h (as on meteo.cat's summit pages).
                            'wind': None if vals.get('velocitat vent') is None else round(vals['velocitat vent'] * KMH_TO_KN, 1)}
                out.append(row)
            except (KeyError, ValueError, TypeError):
                continue
        return out
