"""Assembles the app's JSON contract (same shapes as app/assets/sample/*.json) from live data."""
from __future__ import annotations

import hashlib
import logging
import math
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from . import engine as E
from .config import settings
from .sources import WAVE_MODELS, WEATHER_MODELS, Sources
from . import wingcalc as W
from .meteocat import Meteocat
from .spots import COMARCA_NAMES, HOME, SPORT_SPOT, SPOTS

log = logging.getLogger('oratge')
TZ = ZoneInfo(settings.tz)
WD = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
SPORT_WORD = {'wing': 'Wing', 'surf': 'Surf', 'bike': 'Bike', 'run': 'Run', 'hike': 'Hike'}
SPORT_TITLE = {'wing': 'Wing foil', 'surf': 'Surf', 'bike': 'Bike', 'run': 'Run', 'hike': 'Hike'}


def today_local() -> date:
    return datetime.now(TZ).date()


def date_line(d: date | None = None, place: str | None = None) -> str:
    d = d or today_local()
    return f'{WD[d.weekday()]} {d.day} {MONTHS[d.month - 1]} · {place or HOME["name"]}'


def n(x) -> str:
    """14.0 → '14', 0.6 → '0.6'."""
    x = float(x)
    return str(int(x)) if x == int(x) else f'{x:g}'


def rng(lo: float, hi: float, unit: str = '') -> str:
    a, b = round(lo), round(hi)
    return f'{a}{unit}' if a == b else f'{a}–{b}{unit}'


def hh(h: int) -> str:
    return f'{h:02d} h'


def win(w) -> str:
    return f'{w[0]:02d}–{w[1]:02d} h'


METEOR_EN = {'Vent': 'Wind', 'Neu': 'Snow', 'Calor': 'Heat', 'Calor intensa': 'Heat', 'Fred': 'Cold', 'Fred intens': 'Cold',
             'Estat de la mar': 'Sea state', 'Onada de calor': 'Heatwave', 'Onada de fred': 'Cold wave'}


def meteor_en(name: str) -> str:
    """Meteocat hazard name in English (prefix match covers variants such as 'Intensitat de pluja en 30 minuts')."""
    for ca, en in (('Intensitat de pluja', 'Heavy rain'), ('Acumulació de pluja', 'Rain (24 h total)'), ('Neu', 'Snow')):
        if name.startswith(ca):
            return en
    return METEOR_EN.get(name, name)


def threshold_en(s: str) -> str:
    """Thresholds as Meteocat words them (checked live 2026-11-11), in English:
    'Ratxa màxima > 90 km/h (25 m/s)' → 'gusts above 90 km/h'; 'Intensitat > 20 mm / 30 minuts' → 'over 20 mm in 30 min';
    'Acumulada > 100 mm /24 hores' → 'over 100 mm in 24 h'."""
    import re
    s = re.sub(r'\s*\([^)]*m/s\)', '', s or '').strip()
    s = re.sub(r'(?:Intensitat|Acumulada|Acumulació)\s*>\s*([\d.,]+)\s*(mm|cm)\s*/\s*(\d+)\s*(minuts|hores|hora)',
               lambda m: f'over {m[1]} {m[2]} in {m[3]} {"min" if m[4] == "minuts" else "h"}', s)
    for ca, en in (('Ratxa màxima', 'gusts'), ('Temperatura màxima', 'max temperature'),
                   ('Temperatura mínima', 'min temperature'), ('Onada', 'waves'), (' > ', ' above '), (' < ', ' below ')):
        s = s.replace(ca, en)
    return s


LIVE_MAX_AGE_MIN = 90  # station readings older than this are not shown as "now"


class Builder:
    def __init__(self, src: Sources, profile: dict | None = None, custom: dict | None = None):
        self.src = src
        self.p = {**E.DEFAULT_PROFILE, **(profile or {})}
        # A user-added spot ("activity to check") replaces the built-in spot of its sport.
        self.custom = custom

    def spot_for(self, sport: str) -> dict:
        if self.custom and self.custom.get('sport') == sport:
            return self.custom
        return SPOTS[SPORT_SPOT[sport]]

    # ── data per spot ──
    def hours(self, spot: dict, summit: bool = False) -> list[E.Hour]:
        fc = self.src.forecast(spot['lat'], spot['lon'])
        self._sun = {d: (r, ss) for d, r, ss in zip(fc['daily']['time'], fc['daily']['sunrise'], fc['daily']['sunset'])}
        marine = None
        if spot.get('sport') in ('wing', 'surf'):
            try:
                marine = self.src.marine(spot['lat'], spot['lon'])
            except Exception as e:
                log.warning('marine unavailable: %s', e)
        hours = E.parse_hours(fc, marine)
        if summit and spot.get('summit_alt'):
            # Open-Meteo forecasts for the grid cell's elevation; apply the standard lapse rate to the summit.
            dz = (spot['summit_alt'] - float(fc.get('elevation') or spot.get('base_alt', 1200))) / 1000
            for h in hours:
                h.temp -= 6.5 * dz
                h.feels -= 6.5 * dz + 0.15 * h.wind
                h.wind *= 1 + 0.25 * max(0, dz)
                h.gust *= 1 + 0.3 * max(0, dz)
        return hours

    def rated_day(self, sport: str, day: date, hours: list[E.Hour] | None = None) -> list[E.Rated]:
        spot = self.spot_for(sport)
        hours = hours or self.hours(spot, summit=sport == 'hike')
        return [E.rate(sport, h, spot, self.p) for h in E.day_hours(hours, day)]

    def day_ratings(self, sport: str, hours: list[E.Hour]) -> list[dict]:
        spot = self.spot_for(sport)
        t0 = today_local()
        out = []
        for i in range(8):
            d = t0 + timedelta(days=i)
            rs = [E.rate(sport, h, spot, self.p).rating for h in E.day_hours(hours, d)]
            out.append({'weekday': WD[d.weekday()], 'date': d.day, 'rating': max(rs) if rs else 0, 'outlook': i > 2})
        return out

    def length(self, sport: str) -> int | None:
        if sport == 'bike':
            return 3
        if sport == 'run':
            return 1 if float(self.p.get('runDistance', 10)) <= 12 else 2
        return None

    # ── per-sport summary for Today / Activities ──
    def summary(self, sport: str) -> dict:
        rated = self.rated_day(sport, today_local())
        w = E.best_window(rated, self.length(sport))
        if not w:
            peak = max((r.rating for r in rated), default=0)
            return {'sport': sport, 'rating': peak, 'window': '—', 'reason': self.reason(sport, rated, None)}
        return {'sport': sport, 'rating': w[2], 'window': win(w), 'reason': self.reason(sport, rated, w)}

    def reason(self, sport: str, rated: list[E.Rated], w) -> str:
        inside = [r.hour for r in rated if w and w[0] <= r.hour.t.hour < w[1]] or [r.hour for r in rated]
        if not inside:
            return 'no data'
        mid = inside[len(inside) // 2]
        if sport == 'wing':
            spot = self.spot_for(sport)
            lo, hi = min(h.wind for h in inside), max(h.wind for h in inside)
            return f'{E.shore_relation(mid.wdir, spot["shore_facing"])} {E.compass(mid.wdir)} {rng(lo, hi)} kn'
        if sport == 'surf':
            per = mid.swell_period or mid.period or 0
            return f'{E.compass(mid.swell_dir or 0)} swell {(mid.swell or mid.wave or 0):.1f} m at {per:.0f} s'
        if sport == 'bike':
            wet = [r.hour for r in rated if r.hour.precip >= 0.2]
            return f'showers from {hh(wet[0].t.hour)}' if wet else f'dry · {E.compass(mid.wdir)} {mid.wind:.0f} kn'
        if sport == 'run':
            return f'{min(h.temp for h in inside):.0f}–{max(h.temp for h in inside):.0f}°, UV {max(h.uv for h in inside):.0f}'
        storms = [r.hour for r in rated if r.hour.storm >= float(self.p['maxStorm'])]
        return f'{storms[0].storm:.0f} % storm risk from {hh(storms[0].t.hour)}' if storms else f'summit {mid.temp:.0f}°, {mid.wind:.0f} kn'

    # ── Today ──
    def today(self, place: dict | None = None) -> dict:
        place = place or HOME
        fc = self.src.forecast(place['lat'], place['lon'])
        hours = E.parse_hours(fc)
        now = datetime.now(TZ).replace(tzinfo=None, minute=0, second=0, microsecond=0)
        cur = next((h for h in hours if h.t == now), hours[len(hours) // 2])
        idx = hours.index(cur)
        d0 = fc['daily']
        sports = [self.summary(s) for s in SPORT_SPOT]
        best = max(sports, key=lambda s: (s['rating'], s['window'] != '—'))
        nxt = hours[idx:idx + 24]
        dry = all(h.precip < 0.1 for h in hours[idx:idx + 2])
        live = self.live(place)
        src_line = (f'Meteocat · {live["station_name"]} station · {live["age"]}' if live
                    else 'Open-Meteo model · this hour')
        temp = live['temp'] if live and live.get('temp') is not None else cur.temp
        wind = live['wind'] if live and live.get('wind') is not None else cur.wind
        gust = live['gust'] if live and live.get('gust') is not None else cur.gust
        wdir = live['wdir'] if live and live.get('wdir') is not None else cur.wdir
        days = [{'day': 'Today' if i == 0 else WD[date.fromisoformat(t).weekday()],
                 'sky': day_sky(hours, t, int(d0['weather_code'][i] or 0)),
                 'rainChance': int(d0['precipitation_probability_max'][i] or 0),
                 'min': round(d0['temperature_2m_min'][i]), 'max': round(d0['temperature_2m_max'][i])}
                for i, t in enumerate(d0['time']) if date.fromisoformat(t) >= today_local()][:7]
        lo = min(x['min'] for x in days) - 2
        hi = max(x['max'] for x in days) + 1
        marine = None
        try:
            marine = self.src.marine(SPOTS['castelldefels']['lat'], SPOTS['castelldefels']['lon'])
        except Exception:
            pass
        sst = next((v for v in (marine or {}).get('hourly', {}).get('sea_surface_temperature', [])[idx:] if v is not None), None)
        uv_max_i = max(range(len(nxt)), key=lambda i: nxt[i].uv) if nxt else 0
        rain_next = next((h for h in nxt if h.pprob >= 30), None)
        return {
            'title': 'Today', 'date': date_line(place=place['name']),
            'place': {'name': place['name'], 'lat': place['lat'], 'lon': place['lon']},
            'best': {'sport': best['sport'], 'window': best['window'], 'rating': best['rating'],
                     'reason': best['reason'][:1].upper() + best['reason'][1:] + '.',
                     'note': 'Dry for the next 2 hours (forecast)' if dry else 'Rain likely within 2 hours (forecast)'},
            'warnings': self.warnings(place),
            'observed': (obs := self.observed(place, live)),
            'current': {'place': place['name'], 'source': src_line, 'sky': (sky := now_sky(cur, obs)), 'temp': round(temp),
                        'summary': ('Thunderstorm nearby' if sky == 'storm' and cur.sky != 'storm'
                                    else SUMMARY.get(sky, 'Variable')), 'feels': round(cur.feels),
                        'min': round(d0['temperature_2m_min'][1]), 'max': round(d0['temperature_2m_max'][1]),
                        'wind': f'{E.compass(wdir)} {wind:.0f} kn · gusts {gust:.0f}'},
            'rightNow': [
                {'label': 'Wind', 'value': f'{wind:.0f} kn', 'sub': f'{E.compass(wdir)} · gusts {gust:.0f}', 'accent': 'wind', 'size': 'lg'},
                {'label': 'Rain', 'value': f'{cur.pprob:.0f} %', 'sub': f'likely from {hh(rain_next.t.hour)}' if rain_next else 'dry next 24 h', 'accent': 'water', 'size': 'lg'},
                {'label': 'UV', 'value': f'{cur.uv:.0f}', 'sub': f'max {nxt[uv_max_i].uv:.0f} at {hh(nxt[uv_max_i].t.hour)}' if nxt else '', 'accent': 'sun', 'size': 'lg'},
                {'label': 'Water', 'value': f'{sst:.1f}°' if sst is not None else '—', 'sub': wetsuit(sst) if sst else 'no data', 'accent': 'water', 'size': 'lg'},
            ],
            'next24': {'startHour': nxt[0].t.hour if nxt else 0, 'temps': [round(h.temp, 1) for h in nxt],
                       'rain': [round(h.pprob) for h in nxt], 'sky': [h.sky for h in nxt],
                       'wind': [round(h.wind, 1) for h in nxt], 'gust': [round(h.gust, 1) for h in nxt],
                       'wdir': [round(h.wdir) for h in nxt], 'uv': [round(h.uv, 1) for h in nxt],
                       'feels': [round(h.feels, 1) for h in nxt], 'humidity': [round(h.rh) for h in nxt],
                       'precip': [round(h.precip, 1) for h in nxt], 'storm': [h.storm for h in nxt]},
            'sports': sports, 'days': days, 'scale': [lo, hi],
            'confidence': self.confidence(),
            'daylight': [{'label': 'Sunrise', 'value': d0['sunrise'][1][11:16]},
                         {'label': 'Sunset', 'value': d0['sunset'][1][11:16], 'sub': f'last light {last_light(d0["sunset"][1][11:16])}'}],
            'sources': ('Meteocat (SMC): XEMA station readings, lightning (XDDE), warnings; ' if self.src.meteocat_available() else '')
                       + 'Open-Meteo forecast (hourly, 7 days), marine (sea temperature), ECMWF ensemble (confidence)',
        }

    def confidence(self) -> dict | None:
        try:
            ens = self.src.ensemble(HOME['lat'], HOME['lon'], 'temperature_2m')
        except Exception:
            return None
        h = ens['hourly']
        members = [k for k in h if k.startswith('temperature_2m')]
        rows = []
        for i, d in enumerate(sorted({t[:10] for t in h['time']})[:3]):
            idx = [j for j, t in enumerate(h['time']) if t.startswith(d) and 9 <= int(t[11:13]) <= 18]
            spreads = []
            for j in idx:
                vals = [h[m][j] for m in members if h[m][j] is not None]
                spreads.append(E.percentile(vals, 0.9) - E.percentile(vals, 0.1))
            s = sum(spreads) / len(spreads) if spreads else 0
            pct = max(30, min(98, round(100 - s * 12)))
            rows.append({'day': 'Today' if i == 0 else WD[date.fromisoformat(d).weekday()],
                         'label': f'temperature spread {s:.1f}°', 'pct': pct})
        return {'intro': f'Share of {len(members)} ensemble members (ECMWF ENS) that agree with the blend within your thresholds.',
                'rows': rows}

    # ── Meteocat pieces (only with a key) ──
    def warnings(self, place: dict | None = None) -> list[dict]:
        """Open Meteocat warnings that touch the comarques of your spots or home, worst first.

        Structure (checked live 2026-11-11): episode → avisos → evolucions (per day) → periodes (6 h) → afectacions,
        each with idComarca and perill (SMC danger grade 1–6: 1–2 yellow, 3–4 orange, 5–6 red)."""
        if not self.src.meteocat_available():
            return []
        d = today_local()
        data = self.src.try_meteocat('prediccio', f'/pronostic/v2/smp/episodis-oberts?data={d:%Y-%m-%d}Z', 12 * 3600)  # 2/day ≈ 60 of the 100
        mine: dict[int, list[str]] = {}
        for sp in [*SPOTS.values(), HOME]:
            for c in sp.get('comarques', []):
                mine.setdefault(c, []).append(sp['name'])
        if place and place is not HOME and 'comarques' not in place:
            com = self.mc.comarca(place['lat'], place['lon'])  # a searched place or the current location
            if com:
                mine.setdefault(com[0], []).insert(0, place['name'])
                COMARCA_NAMES.setdefault(com[0], com[1])
        found: dict[tuple, dict] = {}
        for ep in data or []:
            try:
                meteor = (ep.get('meteor') or {}).get('nom', '')
                for av in ep.get('avisos') or []:
                    pre = not (av.get('tipus') or '').lower().startswith('av')  # 'Avís' = warning; otherwise a heads-up
                    for ev in av.get('evolucions') or []:
                        day = date.fromisoformat(ev['dia'][:10])
                        for per in ev.get('periodes') or []:
                            for af in per.get('afectacions') or []:
                                c = af.get('idComarca')
                                if c not in mine:
                                    continue
                                # Periods are UTC 6 h blocks ('18-00'): convert to local time.
                                start, _ = (int(x) for x in per['nom'].split('-'))
                                t0 = datetime(day.year, day.month, day.day, start, tzinfo=timezone.utc).astimezone(TZ)
                                rec = found.setdefault((meteor, c), {'perill': 0, 'slots': [], 'pre': pre, 'llindar': ''})
                                if int(af.get('perill') or 1) >= rec['perill']:
                                    rec['llindar'] = af.get('llindar') or ev.get('llindar1') or ''
                                rec['perill'] = max(rec['perill'], int(af.get('perill') or 1))
                                rec['slots'].append((t0, t0 + timedelta(hours=6)))
            except Exception as e:
                log.info('warning parse failed: %s', e)
        # One card per hazard, level and threshold: the affected spots listed together, times merged.
        groups: dict[tuple, dict] = {}
        for (meteor, c), rec in found.items():
            level = 'red' if rec['perill'] >= 5 else ('orange' if rec['perill'] >= 3 else 'yellow')
            g = groups.setdefault((meteor, level, threshold_en(rec['llindar']), rec['pre']),
                                  {'perill': 0, 'slots': [], 'names': [], 'comarques': []})
            g['perill'] = max(g['perill'], rec['perill'])
            g['slots'] += rec['slots']
            g['names'] += mine[c]
            g['comarques'].append(COMARCA_NAMES.get(c, f'comarca {c}'))
        out = []
        for (meteor, level, thr, pre), g in sorted(groups.items(), key=lambda kv: (-kv[1]['perill'], min(kv[1]['slots']))):
            slots = sorted(g['slots'])
            a, b = slots[0][0], max(sl[1] for sl in slots)
            same = a.date() == (b - timedelta(minutes=1)).date()
            when = (f'{WD[a.weekday()]} {a.hour:02d}–{b.hour or 24:02d} h' if same
                    else f'{WD[a.weekday()]} {a.hour:02d} h – {WD[b.weekday()]} {b.hour:02d} h')
            out.append({'level': level, 'pre': pre,
                        'title': f'{level.capitalize()} {"heads-up" if pre else "warning"} · {meteor_en(meteor)}',
                        'detail': ' · '.join(x for x in (', '.join(dict.fromkeys(g['names'])), when, thr) if x),
                        'areas': sorted(set(g['comarques']))})
        return out[:4]

    @property
    def mc(self) -> Meteocat:
        return Meteocat(self.src)

    def live(self, place: dict) -> dict | None:
        """Latest XEMA readings for a place: its own station if it has one, else the closest (≤ 30 km);
        wind from the closest anemometer when that station has none. Key needed."""
        try:
            live = self.mc.live(place['lat'], place['lon'], place.get('station'), place.get('wind_station'))
            # Older than 90 min (daily budget used, station offline): not "now" any more — use the model.
            return live if live and live.get('age_min', 0) <= LIVE_MAX_AGE_MIN else None
        except Exception as e:
            log.info('live failed: %s', e)
            return None

    def observed(self, place: dict, live: dict | None) -> dict | None:
        """Station extras and lightning for the Today screen (same response as the live reading)."""
        if not live:
            return None
        trend = live.get('pressure_trend')
        return {
            'station': live['station_name'], 'km': live.get('station_km'), 'at': live['at'],
            'windStation': live.get('wind_station_name'),
            'humidity': live.get('humidity'), 'pressure': live.get('pressure'), 'pressureTrend': trend,
            'pressureWord': None if trend is None else ('falling fast' if trend <= -2 else 'falling' if trend <= -0.8
                                                       else 'rising' if trend >= 0.8 else 'steady'),
            'rain3h': live.get('rain_3h'), 'rainToday': live.get('rain_today'), 'uv': live.get('uv'),
            'solar': live.get('solar'), 'snow': live.get('snow'),
            'lightning': self.mc.lightning(place['lat'], place['lon']),
        }

    # ── Planner ──
    def planner(self, sport: str, day: int = 0) -> dict:
        spot = self.spot_for(sport)
        hours = self.hours(spot, summit=sport == 'hike')
        the_day = today_local() + timedelta(days=day)
        rated = [E.rate(sport, h, spot, self.p) for h in E.day_hours(hours, the_day)]
        if not rated:
            raise ValueError('no forecast for that day')
        w = E.best_window(rated, self.length(sport))
        peak = max(rated, key=lambda r: (r.rating, r.total))
        sunrise, sunset = self.sun(hours, the_day)
        chart = {'hours': E.HOURS[:len(rated)], 'rows': self.rows(sport, rated, spot), 'sunrise': sunrise, 'sunset': sunset}
        if w:
            chart['best'] = [w[0], w[1]]
        days = self.day_ratings(sport, hours)
        conf, analysis = self.analysis(sport, spot, rated, peak)
        title = f'{SPORT_TITLE[sport]} · {spot["name"]}'
        return {
            'sport': sport, 'title': title, 'date': date_line(the_day), 'days': days, 'selected': day,
            'verdict': {'rating': w[2] if w else peak.rating, 'best': self.best_text(sport, w, rated),
                        'summary': self.verdict_text(sport, rated, w, spot), 'confidence': conf},
            **self.key_facts(sport, rated, w, peak),
            'chip': CHIPS.get(sport),
            'takeaway': self.takeaway(sport, rated, w),
            'hourChart': chart,
            'tuned': self.tuned(sport, rated, w),
            'visuals': self.visuals(sport, spot, hours, rated, w) + (self.meteocat_sections(sport, spot, rated) if day == 0 else []),
            'plan': self.plan(sport, rated, w, sunrise, sunset, hours),
            'outlook': self.outlook(sport, spot, hours),
            'analysis': analysis,
            'sources': SOURCES[sport] + ('' if self.src.meteocat_available() else ' (Meteocat joins once the API key is set)'),
        }

    def sun(self, hours, day):
        """Decimal sunrise/sunset hours for the day (from the forecast's daily block)."""
        ev = getattr(self, '_sun', {}).get(str(day))
        if ev:
            r, s_ = ev
            return int(r[11:13]) + int(r[14:16]) / 60, int(s_[11:13]) + int(s_[14:16]) / 60
        dl = [h.t.hour for h in hours if h.t.date() == day and h.daylight]
        return (min(dl) if dl else 7.6, (max(dl) + 1) if dl else 17.6)

    def best_text(self, sport, w, rated) -> str:
        if not w:
            return 'No good window today'
        if sport == 'hike':
            storms = [r.hour.t.hour for r in rated if r.hour.storm >= float(self.p['maxStorm'])]
            spot = self.spot_for('hike')
            ascent = math.ceil(((spot.get('summit_alt') or 0) - (spot.get('base_alt') or 0)) / float(self.p.get('climbPace', 400)))
            first_light = min((r.hour.t.hour for r in rated if r.hour.daylight), default=8)
            start = max(first_light, w[0] - ascent)
            if storms:
                return f'Start {start:02d}:30 · turn back by {storms[0] - 1:02d}:00'
            dark = [r.hour.t.hour for r in rated if not r.hour.daylight and r.hour.t.hour > 12]
            back = (dark[0] if dark else 18) - int(float(self.p.get('daylightMargin', 1)))
            return f'Start {start:02d}:30 · summit {w[0]:02d}–{w[1]:02d} h · down by {back:02d}:00'
        if sport == 'bike':
            return f'Leave {w[0]:02d}:00 → back {min(w[1], w[0] + 3):02d}:00'
        if sport == 'run':
            return f'Go {w[0]:02d}:00–{w[1]:02d}:00'
        top = [r.hour.t.hour for r in rated if r.rating == w[2]]
        peak = f' · peak {top[0]:02d}–{top[-1] + 1:02d} h' if top and (top[-1] + 1 - top[0]) < (w[1] - w[0]) else ''
        return f'Best {win(w)}{peak}'

    def verdict_text(self, sport, rated, w, spot) -> str:
        hs = [r.hour for r in rated if w and w[0] <= r.hour.t.hour < w[1]] or [r.hour for r in rated]
        if sport == 'wing':
            rel = E.shore_relation(hs[len(hs) // 2].wdir, spot['shore_facing'])
            morning_off = [r.hour for r in rated if E.shore_relation(r.hour.wdir, spot['shore_facing']) == 'off']
            return (f'{rel.capitalize()} {E.compass(hs[0].wdir)} {rng(min(h.wind for h in hs), max(h.wind for h in hs))} kn, '
                    f'gusts ≤ {max(h.gust for h in hs):.0f}. Chop up to {max((h.wave or 0) for h in hs):.1f} m.'
                    + (f' Offshore around {hh(morning_off[0].t.hour)}, so stay ashore then.' if morning_off else ''))
        if sport == 'surf':
            h = hs[0]
            return (f'{E.compass(h.swell_dir or 0)} swell {(h.swell or h.wave or 0):.1f} m at {(h.swell_period or h.period or 0):.0f} s, '
                    f'wind {E.shore_relation(h.wdir, spot["shore_facing"])} {h.wind:.0f} kn.')
        if sport == 'bike':
            wet = [r.hour for r in rated if r.hour.precip >= 0.2]
            return (f'{"Showers from " + hh(wet[0].t.hour) + "." if wet else "Dry all day."} '
                    f'{E.compass(hs[0].wdir)} {hs[0].wind:.0f} kn, {min(h.temp for h in hs):.0f}–{max(h.temp for h in hs):.0f}°.')
        if sport == 'run':
            warm = max(rated, key=lambda r: r.hour.feels).hour
            return (f'{min(h.temp for h in hs):.0f}–{max(h.temp for h in hs):.0f}° in the window. '
                    f'Warmest at {hh(warm.t.hour)}, feels {warm.feels:.0f}° with UV {warm.uv:.0f}.')
        top = max(rated, key=lambda r: r.hour.storm).hour
        return (f'Summit {hs[0].temp:.0f}° and {E.compass(hs[0].wdir)} {hs[0].wind:.0f} kn early. '
                f'Storm risk peaks at {top.storm:.0f} % around {hh(top.t.hour)}.')

    def key_facts(self, sport, rated, w, peak) -> dict:
        hs = [r.hour for r in rated if w and w[0] <= r.hour.t.hour < w[1]] or [r.hour for r in rated if r.hour.daylight] or [peak.hour]
        f = lambda label, value, sub, accent: {'label': label, 'value': value, 'sub': sub, 'accent': accent, 'size': 'lg'}  # noqa: E731
        if sport == 'wing':
            g = max(hs, key=lambda h: h.gust)
            return {'keyLabel': 'In the window', 'keyFacts': [
                f('Wind', rng(min(h.wind for h in hs), max(h.wind for h in hs), ' kn'), E.compass(hs[0].wdir), 'wind'),
                f('Gusts', f'≤ {g.gust:.0f} kn', f'peak {hh(g.t.hour)}', 'wind'),
                f('Waves', f'{max((h.wave or 0) for h in hs):.1f} m', 'chop', 'water'),
                f('Air', f'{hs[0].temp:.0f}°', f'feels {hs[0].feels:.0f}°', 'heat')]}
        if sport == 'surf':
            h = hs[0]
            return {'keyLabel': 'In the window', 'keyFacts': [
                f('Swell', f'{(h.swell or h.wave or 0):.1f} m', E.compass(h.swell_dir or 0), 'water'),
                f('Period', f'{(h.swell_period or h.period or 0):.0f} s', 'groundswell' if (h.swell_period or 0) >= 9 else 'wind swell', 'water'),
                f('Wind', f'{h.wind:.0f} kn', f'{E.compass(h.wdir)}', 'wind'),
                f('Water', f'{h.sst:.1f}°' if h.sst else '—', wetsuit(h.sst), 'water')]}
        if sport == 'bike':
            wet = [r.hour for r in rated if r.hour.precip >= 0.2]
            return {'keyLabel': 'On the ride', 'keyFacts': [
                f('Showers', hh(wet[0].t.hour) if wet else 'none', f'up to {max(r.hour.precip for r in rated):.1f} mm' if wet else 'dry all day', 'water'),
                f('Wind', f'{hs[0].wind:.0f} kn', f'{E.compass(hs[0].wdir)} · gusts {max(h.gust for h in hs):.0f}', 'wind'),
                f('Temp', f'{min(h.temp for h in hs):.0f}–{max(h.temp for h in hs):.0f}°', f'feels {min(h.feels for h in hs):.0f}–{max(h.feels for h in hs):.0f}°', 'heat'),
                f('UV', f'{max(h.uv for h in hs):.0f}', uv_word(max(h.uv for h in hs)), 'sun')]}
        if sport == 'run':
            h = hs[0]
            return {'keyLabel': 'At go time', 'keyFacts': [
                f('Temp', f'{h.temp:.0f}°', f'feels {h.feels:.0f}°', 'heat'), f('Wind', f'{h.wind:.0f} kn', 'calm' if h.wind < 6 else E.compass(h.wdir), 'wind'),
                f('Rain', f'{h.pprob:.0f} %', 'dry' if h.precip < 0.1 else 'showers', 'water'), f('UV', f'{h.uv:.0f}', uv_word(h.uv), 'sun')]}
        st = max(rated, key=lambda r: r.hour.storm).hour
        h = hs[0]
        return {'keyLabel': 'On the summit', 'keyFacts': [
            f('Storm', f'{st.storm:.0f} %', f'at {hh(st.t.hour)}', 'storm'), f('Summit', f'{h.temp:.0f}°', f'at {hh(h.t.hour)}', 'snow'),
            f('Wind', f'{h.wind:.0f} kn', f'{E.compass(h.wdir)} · gusts {h.gust:.0f}', 'wind'),
            f('Snow level', f'{max(0, round((h.freezing - 300) / 100) * 100)} m', 'from freezing level', 'snow')]}

    def rows(self, sport, rated, spot) -> list[dict]:
        hs = [r.hour for r in rated]
        rows = [{'type': 'icons', 'label': 'Sky', 'values': [h.sky for h in hs]},
                {'type': 'rating', 'label': 'Rating', 'values': [r.rating for r in rated]}]
        if sport == 'wing':
            rows += [{'type': 'line', 'label': 'Wind', 'unit': 'kn', 'accent': 'wind', 'min': 0, 'max': 30,
                      'range': [self.p['windFrom'], self.p['windTo']], 'rangeLabel': f'your range {n(self.p["windFrom"])}–{n(self.p["windTo"])}',
                      'values': [round(h.wind) for h in hs], 'band': [round(h.gust) for h in hs],
                      'labelAt': [max(range(len(hs)), key=lambda i: hs[i].wind)], 'height': 96},
                     {'type': 'arrows', 'label': 'From', 'unit': 'vs shore', 'accent': 'wind', 'directions': [round(h.wdir) for h in hs],
                      'shore': [E.shore_relation(h.wdir, spot['shore_facing']) for h in hs]},
                     {'type': 'numbers', 'label': 'Gust', 'unit': 'kn', 'values': [round(h.gust) for h in hs], 'emphasizeAbove': float(self.p['gustLimit']) - 4},
                     {'type': 'bars', 'label': 'Waves', 'unit': 'm', 'accent': 'water', 'max': 1.5, 'labelEvery': 3, 'decimals': 1, 'values': [round(h.wave or 0, 1) for h in hs]},
                     {'type': 'numbers', 'label': 'Air', 'unit': '°C', 'suffix': '°', 'values': [round(h.temp) for h in hs]},
                     {'type': 'bars', 'label': 'Rain', 'unit': '%', 'accent': 'water', 'max': 100, 'labelEvery': 3, 'values': [round(h.pprob) for h in hs]}]
        elif sport == 'surf':
            rows += [{'type': 'bars', 'label': 'Waves', 'unit': 'm', 'accent': 'water', 'max': 2, 'labelEvery': 2, 'decimals': 1, 'values': [round(h.swell or h.wave or 0, 1) for h in hs], 'height': 60},
                     {'type': 'numbers', 'label': 'Period', 'unit': 's', 'values': [round(h.swell_period or h.period or 0) for h in hs], 'emphasizeAbove': float(self.p['minPeriod']) - 0.5},
                     {'type': 'arrows', 'label': 'Wind', 'unit': 'vs shore', 'accent': 'wind', 'directions': [round(h.wdir) for h in hs],
                      'shore': [E.shore_relation(h.wdir, spot['shore_facing']) for h in hs], 'offshoreGood': True},
                     {'type': 'numbers', 'label': 'Speed', 'unit': 'kn', 'values': [round(h.wind) for h in hs]},
                     {'type': 'numbers', 'label': 'Air', 'unit': '°C', 'suffix': '°', 'values': [round(h.temp) for h in hs]}]
        elif sport == 'bike':
            rows += [{'type': 'line', 'label': 'Temp', 'unit': '°C', 'accent': 'heat', 'min': min(h.feels for h in hs) - 2, 'max': max(h.temp for h in hs) + 3,
                      'values': [round(h.temp, 1) for h in hs], 'companion': [round(h.feels, 1) for h in hs], 'labelAt': [0, max(range(len(hs)), key=lambda i: hs[i].temp)], 'height': 80},
                     {'type': 'bars', 'label': 'Rain', 'unit': 'mm', 'accent': 'water', 'max': max(2, max(h.precip for h in hs)), 'labelEvery': 1, 'decimals': 1, 'values': [round(h.precip, 1) for h in hs], 'height': 40},
                     {'type': 'category', 'label': 'Roads', 'values': [road(h) for h in hs],
                      'styles': {'wet': {'accent': 'water', 'opacity': 0.9, 'text': 'wet'}, 'damp': {'accent': 'water', 'opacity': 0.45, 'text': 'damp'}, 'dry': {'accent': 'empty'}}},
                     {'type': 'arrows', 'label': 'Wind', 'accent': 'wind', 'directions': [round(h.wdir) for h in hs]},
                     {'type': 'numbers', 'label': 'Speed', 'unit': 'kn', 'values': [round(h.wind) for h in hs], 'emphasizeAbove': float(self.p['maxWindBike']) * 0.6},
                     {'type': 'bars', 'label': 'UV', 'accent': 'sun', 'max': 8, 'labelEvery': 2, 'values': [round(h.uv) for h in hs], 'height': 30}]
        elif sport == 'run':
            rows += [{'type': 'line', 'label': 'Temp', 'unit': '°C', 'accent': 'heat', 'min': min(h.feels for h in hs) - 2, 'max': max(h.temp for h in hs) + 3,
                      'range': [self.p['comfortFrom'], self.p['comfortTo']], 'values': [round(h.temp, 1) for h in hs], 'companion': [round(h.feels, 1) for h in hs],
                      'labelAt': [0, max(range(len(hs)), key=lambda i: hs[i].temp)], 'height': 80},
                     {'type': 'bars', 'label': 'UV', 'accent': 'sun', 'max': 8, 'labelEvery': 2, 'values': [round(h.uv) for h in hs], 'height': 30},
                     {'type': 'numbers', 'label': 'Wind', 'unit': 'kn', 'values': [round(h.wind) for h in hs]},
                     {'type': 'bars', 'label': 'Rain', 'unit': '%', 'accent': 'water', 'max': 100, 'labelEvery': 3, 'values': [round(h.pprob) for h in hs]}]
        else:
            rows += [{'type': 'bars', 'label': 'Storm', 'unit': '%', 'accent': 'storm', 'max': 100, 'labelEvery': 2, 'values': [h.storm for h in hs], 'height': 40},
                     {'type': 'line', 'label': 'Wind', 'unit': 'kn', 'accent': 'wind', 'min': 0, 'max': max(40, max(h.gust for h in hs) + 4),
                      'values': [round(h.wind) for h in hs], 'band': [round(h.gust) for h in hs], 'labelAt': [max(range(len(hs)), key=lambda i: hs[i].gust)], 'height': 70},
                     {'type': 'numbers', 'label': 'Temp', 'unit': '°C', 'suffix': '°', 'values': [round(h.temp) for h in hs]},
                     {'type': 'numbers', 'label': 'Snow lvl', 'unit': 'm', 'every': 2, 'values': [max(0, round((h.freezing - 300) / 100) * 100) for h in hs]}]
        return rows

    def takeaway(self, sport, rated, w) -> str:
        if not w:
            return 'No hour reaches a usable rating today; check the next days above.'
        hs = [r.hour for r in rated if w[0] <= r.hour.t.hour < w[1]]
        if sport == 'wing':
            top = max(hs, key=lambda h: h.wind)
            return f'Inside your range from {w[0]} to {w[1]} h, peaking at {top.wind:.0f} kn around {top.t.hour} h.'
        if sport == 'surf':
            return f'Best {win(w)}: {(hs[0].swell or hs[0].wave or 0):.1f} m at {(hs[0].swell_period or hs[0].period or 0):.0f} s.'
        if sport == 'bike':
            wet = [r.hour for r in rated if r.hour.precip >= 0.2]
            return f'Dry until {hh(wet[0].t.hour)}, then showers.' if wet else 'Dry all day; best wind and temperature in the window.'
        if sport == 'run':
            warm = max(rated, key=lambda r: r.hour.temp).hour
            return f'Coolest in the window {win(w)}; warmest at {hh(warm.t.hour)} with UV {warm.uv:.0f}.'
        over = [r.hour for r in rated if r.hour.storm >= float(self.p['maxStorm'])]
        top = max(rated, key=lambda r: r.hour.storm).hour
        return (f'Storm risk passes {n(self.p["maxStorm"])} % at {hh(over[0].t.hour)} and peaks at {top.storm:.0f} % at {hh(top.t.hour)}.'
                if over else f'Storm risk stays under {n(self.p["maxStorm"])} % all day.')

    def tuned(self, sport, rated, w) -> list[dict]:
        p = self.p
        if sport == 'wing':
            hs = [r.hour for r in rated if w and w[0] <= r.hour.t.hour < w[1]] or [r.hour for r in rated if r.hour.daylight]
            g = max((h.gust for h in hs), default=0)
            gr = W.gear(p)
            big = max(gr['wings'], key=lambda x: x['size'])
            gear_line = {'from': f'{gr["weight"]:.0f} kg · {gr["board"]:.0f} l · {gr["front_wing"]:.0f} cm² · '
                                 f'{", ".join(f"{x["size"]:g} m" for x in gr["wings"])} · {gr["level"].lower()}',
                         'effect': f'foiling from about {big["low"]:.0f} kn on your {big["size"]:g} m; '
                                   f'gusts up to {gr["max_gust"]:.0f} kn on the smallest wing'}
            warn = ([{'from': 'Your wind range vs your gear',
                      'effect': f'your range starts at {n(p["windFrom"])} kn, your gear needs about {gr["min_wind"]:.0f} kn'}]
                    if float(p['windFrom']) < gr['min_wind'] - 1 else [])
            return [gear_line, *warn,
                    {'from': f'Wind range {n(p["windFrom"])}–{n(p["windTo"])} kn', 'effect': f'rideable from {n(p["windFrom"])} kn'},
                    {'from': f'Gust limit {n(p["gustLimit"])} kn', 'effect': f'peak {g:.0f} kn ' + ('stays inside' if g <= float(p['gustLimit']) else 'is over your limit')},
                    {'from': f'Directions: {", ".join(p["directions"])}', 'effect': 'offshore hours rate 0'}]
        if sport == 'surf':
            return [{'from': f'Waves {n(p["waveFrom"])}–{n(p["waveTo"])} m', 'effect': 'ratings peak inside your range'},
                    {'from': f'Minimum period {n(p["minPeriod"])} s', 'effect': 'shorter periods lower the rating'}]
        if sport == 'bike':
            return [{'from': 'No mudguards' if not p.get('mudguards') else 'Mudguards', 'effect': 'damp roads lower the rating' if not p.get('mudguards') else 'damp roads are fine'},
                    {'from': f'Max wind {n(p["maxWindBike"])} kn', 'effect': 'stronger wind lowers the rating'},
                    {'from': 'Lights fitted' if p.get('lights') else 'No lights', 'effect': 'evening windows count' if p.get('lights') else 'only daylight counts'}]
        if sport == 'run':
            return [{'from': f'Comfortable {n(p["comfortFrom"])}–{n(p["comfortTo"])}°', 'effect': 'the window stays inside that range'},
                    {'from': 'Light rain is fine' if p.get('lightRainOk') else 'Avoids rain', 'effect': 'drizzle only lowers the rating a little' if p.get('lightRainOk') else 'any rain lowers the rating'}]
        return [{'from': f'Max storm risk {n(p["maxStorm"])} %', 'effect': 'turn-back time is set where it is passed'},
                {'from': f'Max summit wind {n(p["maxSummitWind"])} kn', 'effect': 'gusts above it lower the rating'},
                {'from': 'Crampons and ice axe' if p.get('crampons') else 'No crampons', 'effect': 'snow above the snow level is fine' if p.get('crampons') else 'stay below the snow level'}]

    def visuals(self, sport, spot, hours, rated, w) -> list[dict]:
        now = datetime.now(TZ).replace(tzinfo=None, minute=0, second=0, microsecond=0)
        past = [h for h in hours if now - timedelta(hours=11) <= h.t <= now] or hours[:12]
        if sport == 'wing':
            cur = past[-1]
            live = self.live(spot)
            live = live if live and live.get('wind') is not None else None
            wind = live['wind'] if live else cur.wind
            wdir = live['wdir'] if live and live.get('wdir') is not None else cur.wdir
            label = f'Live · {spot.get("wind_station_name") or spot.get("station_name")}' if live else 'At the spot now (model)'
            return [{'label': label, 'blocks': [
                {'type': 'WindCompass', 'props': {'from': round(wdir), 'speed': round(wind), 'shoreFacing': spot['shore_facing'],
                                                  'caption': f'{"live" if live else "model"} · {E.shore_relation(wdir, spot["shore_facing"])}'}},
                {'type': 'TrendLine', 'props': {'accent': 'wind', 'values': [round(h.wind, 1) for h in past], 'band': [round(h.gust, 1) for h in past],
                                                'nowIndex': len(past) - 1, 'nowLabel': f'{wind:.0f} kn', 'caption': [f'−{len(past) - 1} h', 'now'],
                                                'min': 0, 'max': max(24, max(h.gust for h in past) + 2), 'height': 64}}]}]
        if sport == 'surf' and spot.get('exposure'):
            h = rated[len(rated) // 3].hour
            return [{'label': 'Swell window', 'blocks': [{'type': 'SwellWindow', 'props': {'swellFrom': round(h.swell_dir or h.wave_dir or 90), 'exposure': spot['exposure']}}]}]
        if sport == 'bike' and spot.get('route'):
            h = rated[(w[0] - E.HOURS[0]) if w else 2].hour
            return [{'label': f'Route wind · {h.t.hour:02d}:00 start', 'blocks': [{'type': 'RouteWind', 'props': {
                'points': spot['route'], 'windFrom': round(h.wdir), 'windLabel': f'{E.compass(h.wdir)} {h.wind:.0f} kn',
                'title': f'{tail_share(spot["route"], h.wdir)} % tailwind', 'labels': spot.get('route_labels', [])}}]}]
        if sport == 'hike' and spot.get('summit_alt'):
            h = rated[min(4, len(rated) - 1)].hour
            dz = lambda a: (spot['summit_alt'] - a) / 1000 * 6.5  # noqa: E731
            pres = [h2 for h2 in hours if now - timedelta(hours=12) <= h2.t <= now + timedelta(hours=12)]
            return [{'label': 'Temperature by altitude', 'blocks': [{'type': 'AltitudeProfile', 'props': {
                        'snowLevel': max(0, round((h.freezing - 300) / 100) * 100),
                        'points': [{'altitude': spot['base_alt'], 'temp': round(h.temp + dz(spot['base_alt'])), 'label': 'Valley'},
                                   {'altitude': spot['hut_alt'], 'temp': round(h.temp + dz(spot['hut_alt'])), 'label': 'Refugi'},
                                   {'altitude': spot['summit_alt'], 'temp': round(h.temp), 'label': 'Summit'}]}}]},
                    {'label': 'Pressure trend', 'blocks': [{'type': 'TrendLine', 'props': {
                        'accent': 'neutral', 'values': [round(x.pressure, 1) for x in pres],
                        'endLabels': [f'{pres[0].pressure:.0f}', f'{pres[-1].pressure:.0f} hPa'], 'caption': ['−12 h', '+12 h'], 'height': 70}}]}] if pres else []
        return []

    def meteocat_value(self, sport, spot, hour) -> float | None:
        """Meteocat's forecast for the same quantity and hour (cached; no call unless already fetched today)."""
        if hour.t.date() != today_local() or not self.src.meteocat_available():
            return None
        try:
            if sport in ('wing', 'surf') and spot.get('beach'):
                b = next((x for x in self.mc.beach(spot['beach']) if x['hour'] == hour.t.hour), None)
                return None if b is None else (b['wind'] if sport == 'wing' else b['wave'])
            if sport == 'hike' and spot.get('peak_slug'):
                sf = self.mc.summit(spot['peak_slug'])
                x = min(sf, key=lambda r: abs(r['hour'] - hour.t.hour), default=None)
                band = x and (2500 if 2500 in x['levels'] else max(x['levels']))
                return x['levels'][band]['wind'] if x else None
        except Exception:
            return None
        return None

    def meteocat_sections(self, sport, spot, rated) -> list[dict]:
        """Meteocat's own forecast for the spot (beach or summit), next to the model the plan uses.
        Today only: each spot-day costs one of the 100 monthly forecast calls."""
        out = []
        try:
            if sport in ('wing', 'surf') and spot.get('beach'):
                bf = [b for b in self.mc.beach(spot['beach']) if b['hour'] in E.HOURS]
                if bf:
                    model = {r.hour.t.hour: r.hour for r in rated}
                    if sport == 'wing':
                        xs = [b for b in bf if b['wind'] is not None and b['hour'] in model]
                        out.append({'label': 'Meteocat beach forecast', 'blocks': [{'type': 'TrendLine', 'props': {
                            'accent': 'wind', 'values': [b['wind'] for b in xs], 'compare': [round(model[b['hour']].wind, 1) for b in xs],
                            'unit': 'kn', 'caption': [hh(xs[0]['hour']), hh(xs[-1]['hour'])], 'min': 0,
                            'max': max(20, max(max(b['wind'] for b in xs), max(model[b['hour']].wind for b in xs)) + 2), 'height': 64,
                            'legend': ['Meteocat', 'model used for the plan']}}]})
                    rows = [[hh(b['hour']), f'{E.compass(b["wdir"] or 0)} {b["wind"]:.0f} kn' if b['wind'] is not None else '—',
                             f'{b["wave"]:.1f} m' if b['wave'] is not None else '—',
                             f'{b["sst"]:.1f}°' if b['sst'] is not None else '—', f'{b["temp"]:.0f}°' if b['temp'] is not None else '—']
                            for b in bf[::2]]
                    out.append({'label': 'Meteocat beach forecast · by hour' if sport == 'wing' else 'Meteocat beach forecast',
                                'blocks': [{'type': 'Table', 'props': {'columns': ['', 'Wind', 'Waves', 'Water', 'Air'], 'rows': rows,
                                                                        'caption': 'Servei Meteorològic de Catalunya'}}]})
            if sport == 'hike' and spot.get('peak_slug'):
                sf = [x for x in self.mc.summit(spot['peak_slug']) if 6 <= x['hour'] <= 21]
                if sf:
                    band = 2500 if all(2500 in x['levels'] for x in sf) else max(sf[0]['levels'])
                    rows = [[hh(x['hour']), f'{x["levels"][band]["temp"]:.0f}°',
                             f'{E.compass(x["levels"][band]["wdir"] or 0)} {x["levels"][band]["wind"]:.0f} kn',
                             f'{x["levels"][band]["humidity"]:.0f} %', f'{x.get("freezing") or 0:.0f} m'] for x in sf]
                    out.append({'label': f'Meteocat summit forecast · {band} m', 'blocks': [{'type': 'Table', 'props': {
                        'columns': ['', 'Temp', 'Wind', 'Humidity', 'Freezing'], 'rows': rows,
                        'caption': 'Servei Meteorològic de Catalunya · El Pedraforca'}}]})
            if sport in ('hike', 'wing', 'surf'):
                lt = self.mc.lightning(spot['lat'], spot['lon'])
                if lt and lt['count']:
                    out.insert(0, {'label': 'Lightning now', 'blocks': [{'type': 'FactTile', 'props': {
                        'label': 'Strikes within 30 km', 'value': f'{lt["count"]}', 'accent': 'storm', 'size': 'lg',
                        'sub': f'nearest {lt["nearest_km"]} km · last {lt["last"]} · last 2 h (Meteocat)'}}]})
        except Exception as e:
            log.info('meteocat sections %s failed: %s', sport, e)
        return out

    def plan(self, sport, rated, w, sunrise, sunset, hours) -> dict | None:
        ss = f'{int(sunset):02d}:{int((sunset % 1) * 60):02d}'
        sr = f'{int(sunrise):02d}:{int((sunrise % 1) * 60):02d}'
        hs = [r.hour for r in rated if w and w[0] <= r.hour.t.hour < w[1]] or [r.hour for r in rated]
        if sport == 'wing':
            g = max(h.gust for h in hs)
            avg = max(h.wind for h in hs)
            choice = W.pick(W.gear(self.p), avg, g)
            return {'label': 'Plan', 'facts': [{'label': 'Wing', 'value': f'{choice["size"]:g} m',
                                                'sub': choice['text'] if choice['state'] != 'ok' else f'gusts up to {g:.0f} kn'},
                                               {'label': 'Water', 'value': f'{hs[0].sst:.1f}°' if hs[0].sst else '—', 'sub': wetsuit(hs[0].sst)},
                                               {'label': 'Sunset', 'value': ss, 'sub': f'last light {last_light(ss)}'},
                                               {'label': 'Storms', 'value': f'{max(h.storm for h in hs):.0f} %', 'sub': 'risk in the window'}]}
        if sport == 'surf':
            return {'label': 'Plan', 'facts': [{'label': 'Sunrise', 'value': sr}, {'label': 'Air', 'value': f'{hs[0].temp:.0f}°', 'sub': f'at {hh(hs[0].t.hour)}'},
                                               {'label': 'UV max', 'value': f'{max(h.uv for h in hs):.0f}', 'sub': uv_word(max(h.uv for h in hs))},
                                               {'label': 'Water', 'value': f'{hs[0].sst:.1f}°' if hs[0].sst else '—', 'sub': wetsuit(hs[0].sst)}]}
        if sport == 'bike':
            before = [h for h in hours if h.t <= hs[0].t][-6:]
            live = self.live(self.spot_for('bike'))
            measured = live.get('rain_3h') if live else None
            roads = ({'label': 'Roads', 'value': 'Wet' if measured >= 0.3 else ('Damp' if measured > 0 else road(hs[0])),
                      'sub': f'{measured:.1f} mm measured in 3 h ({live["station_name"]})'} if measured is not None
                     else {'label': 'Roads', 'value': road(hs[0]), 'sub': f'{sum(h.precip for h in before):.1f} mm in 6 h'})
            return {'label': 'Plan', 'facts': [roads,
                                               {'label': 'Gusts', 'value': f'{max(h.gust for h in hs):.0f} kn', 'sub': 'max on the ride'},
                                               {'label': 'Sunset', 'value': ss}, {'label': 'UV max', 'value': f'{max(h.uv for h in hs):.0f}'}]}
        if sport == 'run':
            warm = max(rated, key=lambda r: r.hour.temp).hour
            return {'label': 'What to wear', 'facts': [{'label': 'Layer', 'value': layer(hs[0].feels, self.p), 'sub': 'at go time'},
                                                       {'label': 'Hottest', 'value': f'{warm.temp:.0f}°', 'sub': hh(warm.t.hour)},
                                                       {'label': 'UV max', 'value': f'{max(r.hour.uv for r in rated):.0f}'}, {'label': 'Sunrise', 'value': sr}]}
        return {'label': 'Plan', 'facts': [{'label': 'Sunrise', 'value': sr}, {'label': 'Sunset', 'value': ss},
                                           {'label': 'Summit low', 'value': f'{min(h.temp for h in hs):.0f}°', 'sub': 'in the window'},
                                           {'label': 'Freezing level', 'value': f'{hs[0].freezing:.0f} m'}]}

    def outlook(self, sport, spot, hours) -> dict | None:
        t0 = today_local()
        sel = [h for h in hours if t0 <= h.t.date() < t0 + timedelta(days=3)]
        if len(sel) < 48:
            return None
        if sport == 'wing':
            night, start = [], None
            for i, h in enumerate(sel):
                if not h.daylight and start is None:
                    start = i
                if h.daylight and start is not None:
                    night.append([start, i])
                    start = None
            if start is not None:
                night.append([start, len(sel) - 1])
            return {'label': 'Next 3 days', 'block': {'type': 'WindBand', 'props': {
                'mean': [round(h.wind, 1) for h in sel], 'gust': [round(h.gust, 1) for h in sel], 'directions': [round(h.wdir) for h in sel],
                'range': [self.p['windFrom'], self.p['windTo']], 'days': [WD[(t0 + timedelta(days=i)).weekday()] for i in range(3)], 'night': night}}}
        if sport == 'surf':
            s3 = sel[::3]
            return {'label': 'Next 3 days', 'block': {'type': 'WaveBars', 'props': {
                'heights': [round(h.swell or h.wave or 0, 2) for h in s3], 'periods': [round(h.swell_period or h.period or 0) for h in s3],
                'windFrom': [round(h.wdir) for h in s3], 'days': [WD[(t0 + timedelta(days=i)).weekday()] for i in range(3)]}}}
        return None

    def analysis(self, sport, spot, rated, peak) -> tuple[str, dict]:
        hour = peak.hour
        var, unit, models = {'wing': ('wind_speed_10m', 'kn', WEATHER_MODELS), 'bike': ('precipitation', 'mm', WEATHER_MODELS),
                             'run': ('temperature_2m', '°', WEATHER_MODELS), 'hike': ('wind_speed_10m', 'kn', WEATHER_MODELS),
                             'surf': ('wave_height', 'm', WAVE_MODELS)}[sport]
        rows = []
        try:
            mm = self.src.marine_models(spot['lat'], spot['lon']) if sport == 'surf' else self.src.models(spot['lat'], spot['lon'], var)
            ts = hour.t.strftime('%Y-%m-%dT%H:00')
            i = mm['hourly']['time'].index(ts)
            for key, (name, detail) in models.items():
                v = mm['hourly'].get(f'{var}_{key}', [None])[i]
                if v is not None:
                    rows.append({'name': name, 'detail': detail, 'value': round(v, 1)})
        except Exception as e:
            log.info('model agreement unavailable: %s', e)
        own = {'wing': hour.wind, 'bike': hour.precip, 'run': hour.temp, 'hike': hour.wind, 'surf': hour.wave or 0}[sport]
        rows.insert(0, {'name': 'Open-Meteo best match', 'detail': 'blended forecast used for the plan', 'value': round(own, 1)})
        mc = self.meteocat_value(sport, spot, hour)
        if mc is not None:
            rows.insert(1, {'name': 'Meteocat', 'detail': 'beach forecast' if sport != 'hike' else 'summit forecast', 'value': round(mc, 1)})
        n = len(rows)
        for r in rows:
            r['weight'] = round(100 / n)
        vals = [r['value'] for r in rows]
        spread = max(vals) - min(vals) if vals else 0
        blend = round(sum(vals) / len(vals), 1) if vals else 0
        good, ok = {'kn': (4, 8), 'mm': (1, 3), '°': (2, 4), 'm': (0.3, 0.6)}[unit]
        conf = 'High confidence' if spread <= good else ('Medium confidence' if spread <= ok else 'Low confidence')
        agree = 'High agreement.' if spread <= good else ('Medium agreement.' if spread <= ok else 'Models disagree; treat the plan as rough.')
        lo, hi = min(vals + [0]), max(vals) * 1.3 + 1
        ens = self.ensemble_chart(sport, spot, rated)
        out = {'summary': [f'{agree.split(".")[0]} · spread {spread:.1f} {unit}', f'Score {peak.total} / 5', 'Station check after 7 days of data'],
               'model': {'title': f'Model agreement · {var.split("_")[0]} at {hh(hour.t.hour)}', 'unit': unit, 'scale': [round(lo, 1), round(hi, 1)],
                         'blend': blend, 'spread': f'{spread:.1f} {unit}', 'verdict': agree, 'rows': rows},
               'factors': [{'factor': f.name, 'observed': f.observed, 'weight': f.weight, 'score': f.score, 'accent': f.accent} for f in peak.factors],
               'total': f'{peak.total}', 'rating': peak.rating, 'ensemble': ens,
               'station': self.station(sport, spot)}
        if out['station']:
            out['summary'][2] = out['station']['tiles'][0]['value'] + ' station bias'
        return conf, out

    def station(self, sport, spot) -> dict | None:
        from .archive import station_check
        sid = SPORT_SPOT[sport]

        def rate_obs(ts, value):
            # Re-rate the archived forecast hour with the measured value swapped in.
            fc = dict(self.src.store.archived('fc', sid, ts))[ts]
            h = E.Hour(t=datetime.fromisoformat(ts), temp=value if sport in ('bike', 'run') else fc['temp'], feels=fc['temp'],
                       rh=60, precip=0, pprob=0, code=1, wind=value if sport not in ('bike', 'run') else fc['wind'],
                       wdir=fc['wdir'], gust=fc['gust'], uv=2, cape=0, freezing=3000, pressure=1015, cloud=30, daylight=True)
            return E.rate(sport, h, spot, self.p).rating
        try:
            return station_check(self.src.store, sport, sid, today_local(), rate_obs)
        except Exception as e:
            log.info('station check unavailable: %s', e)
            return None

    def ensemble_chart(self, sport, spot, rated) -> dict | None:
        var = {'wing': 'wind_speed_10m', 'hike': 'wind_speed_10m', 'surf': 'wind_speed_10m', 'bike': 'temperature_2m', 'run': 'temperature_2m'}[sport]
        try:
            ens = self.src.ensemble(spot['lat'], spot['lon'], var)
        except Exception:
            return None
        h = ens['hourly']
        members = [k for k in h if k.startswith(var)]
        idx = {t: i for i, t in enumerate(h['time'])}
        p10, p50, p90, chance = [], [], [], []
        lo, hi = (float(self.p['windFrom']), float(self.p['windTo'])) if var.startswith('wind') else (float(self.p['comfortFrom']), float(self.p['comfortTo']))
        for r in rated:
            i = idx.get(r.hour.t.strftime('%Y-%m-%dT%H:00'))
            vals = [h[m][i] for m in members if i is not None and h[m][i] is not None]
            if not vals:
                vals = [0]
            p10.append(round(E.percentile(vals, 0.1), 1))
            p50.append(round(E.percentile(vals, 0.5), 1))
            p90.append(round(E.percentile(vals, 0.9), 1))
            chance.append(round(100 * sum(lo <= v <= hi for v in vals) / len(vals)))
        unit = 'kn' if var.startswith('wind') else '°C'
        accent = 'wind' if unit == 'kn' else 'heat'
        return {'label': f'Ensemble · {"wind" if unit == "kn" else "temperature"}',
                'intro': f'Solid line: ensemble median. Shading up to the 90th percentile, dashed line at the 10th, from {len(members)} members (ECMWF ENS). Bars: chance the value is inside your range.',
                'chart': {'hours': E.HOURS[:len(rated)], 'rows': [
                    {'type': 'line', 'label': f'{"Wind" if unit == "kn" else "Temp"} P50', 'unit': unit, 'accent': accent,
                     'min': min(p10) - 2, 'max': max(p90) + 2, 'values': p50, 'band': p90, 'companion': p10, 'height': 84},
                    {'type': 'bars', 'label': 'In range', 'unit': '%', 'accent': accent, 'max': 100, 'labelEvery': 3, 'values': chance}]}}

    # ── Activities, map, spots ──
    def activities(self) -> dict:
        sports = [self.summary(s) for s in SPORT_SPOT]
        wing_hours = self.hours(SPOTS['castelldefels'])
        heat, months, note = self.history()
        return {'title': 'Activities', 'date': date_line(), 'sports': sports,
                'chip': {'label': 'Planner shows', 'options': ['Today', 'Tomorrow', 'Week'], 'selected': 'Today'},
                'days': self.day_ratings('wing', wing_hours), 'heatmap': heat, 'months': months,
                'sources': f'Ratings from Open-Meteo hourly forecasts and your ranges; history: {note}'}

    def alerts(self, sports: list[str] | None = None, place: dict | None = None) -> dict:
        """Everything worth a notification right now. Stable ids let the app notify each item once.

        window:  a 4–5 rated window for one of your sports today or in the next two days
        warning: an official warning touching your places
        plan:    the current best rating per sport and day (the app compares with what it saw before)"""
        sports = [s for s in (sports or list(SPORT_SPOT)) if s in SPORT_SPOT]
        t0 = today_local()
        out, ratings = [], {}
        for sport in sports:
            spot = self.spot_for(sport)
            hours = self.hours(spot, summit=sport == 'hike')
            for i in range(3):
                day = t0 + timedelta(days=i)
                rated = [E.rate(sport, h, spot, self.p) for h in E.day_hours(hours, day)]
                w = E.best_window(rated, self.length(sport))
                if not w:
                    continue
                ratings[f'{sport}:{day}'] = {'rating': w[2], 'window': win(w), 'sport': sport, 'day': str(day)}
                ended = i == 0 and w[1] <= datetime.now(TZ).hour
                if w[2] >= 4 and not ended:
                    when = 'Today' if i == 0 else ('Tomorrow' if i == 1 else WD[day.weekday()])
                    out.append({'id': f'window:{sport}:{day}:{w[0]}', 'kind': 'window', 'sport': sport,
                                'day': str(day), 'days_ahead': i, 'rating': w[2], 'spot': spot['name'],
                                'title': f'{SPORT_TITLE[sport]}: {ratingword(w[2])} window '
                                         + ('today' if i == 0 else 'tomorrow' if i == 1 else f'on {when}'),
                                'body': f'{spot["name"]} · {when} {win(w)} · {self.reason(sport, rated, w)}',
                                'route': f'/activities/{sport}'})
        for w in self.warnings(place):
            wid = hashlib.md5((w['title'] + w['detail']).encode()).hexdigest()[:12]  # stable across restarts
            out.append({'id': f'warning:{wid}', 'kind': 'warning',
                        'title': w['title'], 'body': w['detail'], 'route': '/today', 'level': w['level']})
        return {'alerts': out, 'ratings': ratings, 'generated': datetime.now(TZ).isoformat(timespec='minutes')}

    def history(self) -> tuple[dict, dict, str]:
        """Rideable hours (wing, Castelldefels) from archived high-resolution forecasts (Open-Meteo
        historical forecast API, 2023→) until the XEMA station archive is long enough."""
        spot = SPOTS['castelldefels']
        end = today_local() - timedelta(days=6)
        start = end - timedelta(days=end.weekday()) - timedelta(weeks=25)
        url = 'https://historical-forecast-api.open-meteo.com/v1/forecast'
        common = dict(latitude=spot['lat'], longitude=spot['lon'], hourly='wind_speed_10m,wind_direction_10m',
                      wind_speed_unit='kn', timezone=settings.tz)

        def per_day(data):
            out = {}
            h = data['hourly']
            for t, ws, wd in zip(h['time'], h['wind_speed_10m'], h['wind_direction_10m']):
                if ws is None or wd is None or not (9 <= int(t[11:13]) <= 18):
                    continue
                ok = float(self.p['windFrom']) <= ws <= float(self.p['windTo']) and E.shore_relation(wd, spot['shore_facing']) != 'off'
                out[t[:10]] = out.get(t[:10], 0) + (1 if ok else 0)
            return out

        weeks, mlabels = [], []
        try:
            recent = per_day(self.src._get(f'om:hist:{start}:{end}', url, dict(common, start_date=str(start), end_date=str(end)), 24 * 3600))
            d = start
            while d + timedelta(days=6) <= end:
                weeks.append([min(5, (recent.get(str(d + timedelta(days=k)), 0) + 1) // 2) for k in range(7)])
                if (d.day <= 7) or not mlabels:
                    mlabels.append(MONTHS[d.month - 1])
                d += timedelta(weeks=1)
        except Exception as e:
            log.info('history unavailable: %s', e)
        months_vals = [0.0] * 12
        try:
            clim_end = today_local().replace(day=1) - timedelta(days=1)
            clim = per_day(self.src._get(f'om:clim:2023-01-01:{clim_end}', url,
                                         dict(common, start_date='2023-01-01', end_date=str(clim_end)), 7 * 24 * 3600))
            days, months_seen = [0] * 12, [set() for _ in range(12)]
            for d, n in clim.items():
                m = int(d[5:7]) - 1
                months_seen[m].add(d[:7])
                days[m] += 1 if n >= 2 else 0
            months_vals = [round(days[m] / max(1, len(months_seen[m])), 1) for m in range(12)]
        except Exception as e:
            log.info('climatology unavailable: %s', e)
        best_m = max(range(12), key=lambda m: months_vals[m])
        return ({'weeks': weeks or [[0] * 7], 'months': mlabels[:7], 'legend': ['0 h', '6+ h']},
                {'values': months_vals, 'highlight': best_m, 'current': today_local().month - 1},
                'archived Open-Meteo forecasts since 2023 (model history; it underestimates the local sea breeze). '
                'XEMA station history replaces it once archived')

    def spots(self) -> dict:
        out = []
        for sid in ('castelldefels', 'ocata', 'collserola', 'pedraforca'):
            s = SPOTS[sid]
            rated = self.rated_day(s['sport'], today_local())
            now = datetime.now(TZ).hour
            cur = next((r.hour for r in rated if r.hour.t.hour == now), rated[0].hour if rated else None)
            w = E.best_window(rated, self.length(s['sport']))
            out.append({'id': sid, 'sport': s['sport'], 'name': s['name'], 'kind': s['kind'],
                        'wind': round(cur.wind) if cur else 0, 'gust': round(cur.gust) if cur else 0, 'windFrom': round(cur.wdir) if cur else 0,
                        'today': [r.rating for r in rated][1::2][:8], 'window': win(w) if w else '—',
                        'rating': w[2] if w else max((r.rating for r in rated), default=0)})
        return {'title': 'Spots', 'date': date_line(), 'spots': out}

    def spot(self, sid: str) -> dict:
        s = SPOTS[sid]
        hours = self.hours(s, summit=s['sport'] == 'hike')
        now = datetime.now(TZ).replace(tzinfo=None, minute=0, second=0, microsecond=0)
        past = [h for h in hours if now - timedelta(hours=11) <= h.t <= now] or hours[:12]
        cur = past[-1]
        live = self.live(s)
        lw = live if live and live.get('wind') is not None else None  # live wind only where a station measures it
        wind, gust = (lw['wind'], lw['gust'] if lw['gust'] is not None else cur.gust) if lw else (cur.wind, cur.gust)
        wdir = lw['wdir'] if lw and lw.get('wdir') is not None else cur.wdir
        facts = [{'label': 'Wind', 'value': f'{wind:.0f} kn', 'sub': E.compass(wdir) + (' · live' if lw else ''), 'accent': 'wind', 'size': 'lg'},
                 {'label': 'Gusts', 'value': f'{gust:.0f} kn', 'sub': 'last 30 min' if lw else 'model, this hour', 'accent': 'wind', 'size': 'lg'}]
        if cur.wave is not None:
            facts += [{'label': 'Waves', 'value': f'{cur.wave:.1f} m', 'sub': f'{cur.period or 0:.0f} s', 'accent': 'water', 'size': 'lg'},
                      {'label': 'Water', 'value': f'{cur.sst:.1f}°' if cur.sst else '—', 'sub': wetsuit(cur.sst), 'accent': 'water', 'size': 'lg'}]
        else:
            facts += [{'label': 'Air', 'value': f'{cur.temp:.0f}°', 'sub': f'feels {cur.feels:.0f}°', 'accent': 'heat', 'size': 'lg'},
                      {'label': 'Rain', 'value': f'{cur.pprob:.0f} %', 'sub': 'this hour', 'accent': 'water', 'size': 'lg'}]
        sections = [{'label': 'Live at the spot' if live else 'At the spot now (model)', 'blocks': [
            *([{'type': 'WindCompass', 'props': {'from': round(cur.wdir), 'speed': round(cur.wind), 'shoreFacing': s['shore_facing'],
                                                 'caption': E.shore_relation(cur.wdir, s['shore_facing'])}}] if 'shore_facing' in s else []),
            {'type': 'TrendLine', 'props': {'accent': 'wind', 'values': [round(h.wind, 1) for h in past], 'band': [round(h.gust, 1) for h in past],
                                            'nowIndex': len(past) - 1, 'nowLabel': f'{cur.wind:.0f} kn', 'caption': [f'−{len(past) - 1} h', 'now'],
                                            'min': 0, 'max': max(24, max(h.gust for h in past) + 2), 'height': 64}}]}]
        if s['sport'] == 'wing':
            heat, months, _ = self.history()
            sections += [{'label': 'Rideable days per month', 'blocks': [{'type': 'MonthBars', 'props': months}]},
                         {'label': 'Rideable hours · last 6 months', 'blocks': [{'type': 'CalendarHeatmap', 'props': heat}]}]
        return {'id': sid, 'title': s['name'], 'date': date_line(), 'live': facts, 'sections': sections,
                'sources': (f'XEMA station {s.get("station_name")}' + (f' + {s["wind_station_name"]} (wind)' if s.get('wind_station') else '') + ' (live), ' if live else '') + 'Open-Meteo forecast and marine; ERA5 history'}

    def map(self) -> dict:
        pins = {'castelldefels': (0.56, 0.74), 'ocata': (0.70, 0.62), 'collserola': (0.62, 0.66), 'pedraforca': (0.48, 0.24)}
        sp = self.spots()['spots']
        return {'title': 'Map', 'date': date_line(),
                'layers': {'options': ['Wind', 'Rating', 'Warnings'], 'selected': 'Wind'},
                'pins': [{'id': x['id'], 'sport': x['sport'], 'window': x['window'], 'gust': x['gust'],
                          'name': x['name'], 'rating': x['rating'], 'x': pins[x['id']][0], 'y': pins[x['id']][1],
                          'lat': SPOTS[x['id']]['lat'], 'lon': SPOTS[x['id']]['lon'],
                          'wind': x['wind'], 'windFrom': x['windFrom']} for x in sp],
                'warnings': self.warnings(),
                'sources': ('Meteocat warnings; ' if self.src.meteocat_available() else 'Warnings need the Meteocat key; ')
                           + 'ratings from your spots (Open-Meteo)'}


def hourly(b: 'Builder', place: dict) -> dict:
    """Seven days, hour by hour, for the metric detail views (Apple/Google-style), plus daily summaries
    and what the nearest Meteocat station measured so far today."""
    fc = b.src.forecast(place['lat'], place['lon'])
    h, d = fc['hourly'], fc['daily']
    t0 = today_local()
    idx = [i for i, t in enumerate(h['time']) if date.fromisoformat(t[:10]) >= t0][:7 * 24]
    pick = lambda k, nd=1: [None if h.get(k) is None or h[k][i] is None else round(h[k][i], nd) for i in idx]  # noqa: E731
    sun = {d['time'][i]: (d['sunrise'][i][11:16], d['sunset'][i][11:16]) for i in range(len(d['time']))}
    series = {
        'temp': pick('temperature_2m'), 'feels': pick('apparent_temperature'), 'humidity': pick('relative_humidity_2m', 0),
        'dew': pick('dew_point_2m'), 'precip': pick('precipitation'), 'pprob': pick('precipitation_probability', 0),
        'wind': pick('wind_speed_10m'), 'gust': pick('wind_gusts_10m'), 'wdir': pick('wind_direction_10m', 0),
        'uv': pick('uv_index'), 'pressure': pick('pressure_msl'), 'cloud': pick('cloud_cover', 0),
        'visibility': [None if v is None else round(v / 1000, 1) for v in pick('visibility', 0)],
    }
    hours = E.parse_hours(fc)
    by_t = {x.t.strftime('%Y-%m-%dT%H:%M'): x for x in hours}
    series['sky'] = [by_t[h['time'][i]].sky if h['time'][i] in by_t else 'cloud' for i in idx]
    series['storm'] = [by_t[h['time'][i]].storm if h['time'][i] in by_t else 0 for i in idx]
    days = []
    for i, t in enumerate(d['time']):
        dd = date.fromisoformat(t)
        if dd < t0 or len(days) >= 7:
            continue
        g = lambda k, nd=0: None if d.get(k) is None or d[k][i] is None else round(d[k][i], nd)  # noqa: E731
        days.append({'date': t, 'day': 'Today' if dd == t0 else WD[dd.weekday()], 'sky': day_sky(hours, t, int(d['weather_code'][i] or 0)),
                     'min': g('temperature_2m_min'), 'max': g('temperature_2m_max'), 'pprob': g('precipitation_probability_max'),
                     'precip': g('precipitation_sum', 1), 'uvMax': g('uv_index_max', 1), 'windMax': g('wind_speed_10m_max'),
                     'gustMax': g('wind_gusts_10m_max'), 'windDir': g('wind_direction_10m_dominant'),
                     'sunrise': sun.get(t, ('', ''))[0], 'sunset': sun.get(t, ('', ''))[1]})
    return {'place': {'name': place['name'], 'lat': place['lat'], 'lon': place['lon']},
            'times': [h['time'][i] for i in idx], 'series': series, 'days': days,
            'observed': observed_today(b, place),
            'sources': 'Open-Meteo forecast' + (' · Meteocat XEMA (measured today)' if b.src.meteocat_available() else '')}


def observed_today(b: 'Builder', place: dict) -> dict | None:
    """Hourly values measured today by the nearest XEMA station (same cached call as the live reading)."""
    if not b.src.meteocat_available():
        return None
    try:
        st = {'code': place['station']} if place.get('station') else b.mc.nearest(place['lat'], place['lon'])
        if not st:
            return None
        v = b.mc.readings(st['code'])
        out: dict[str, dict] = {}
        for code, name, scale in ((32, 'temp', 1), (30, 'wind', 1.94384), (50, 'gust', 1.94384), (33, 'humidity', 1),
                                  (34, 'pressure', 1), (35, 'precip', 1), (39, 'uv', 1)):
            per_hour: dict[str, float] = {}
            for x in v.get(code) or []:
                t = datetime.fromisoformat(x['data'].replace('Z', '+00:00')).astimezone(TZ)
                k = t.strftime('%Y-%m-%dT%H:00')
                val = float(x['valor']) * scale
                per_hour[k] = per_hour.get(k, 0) + val if name == 'precip' else val  # rain adds up, others keep the latest
            if per_hour:
                out[name] = {k: round(val, 1) for k, val in per_hour.items() if k[:10] == str(today_local())}
        return {'station': next((s['name'] for s in b.mc.stations() if s['code'] == st['code']), st['code']), 'series': out}
    except Exception as e:
        log.info('observed today failed: %s', e)
        return None


def map_lightning(b: 'Builder') -> dict:
    """Strikes in Catalonia over the last two hours (XDDE, same cached calls as the planners)."""
    if not b.src.meteocat_available():
        return {'strikes': [], 'source': 'no Meteocat key'}
    now = datetime.now(timezone.utc)
    out = []
    for h, age in ((now - timedelta(hours=1), 7 * 86400), (now, 1200)):
        data = b.src.try_meteocat('xdde', f'/xdde/v1/catalunya/{h:%Y/%m/%d/%H}', age)
        for s_ in data if isinstance(data, list) else []:
            try:
                c = s_.get('coordenades') or s_
                out.append({'lat': float(c.get('latitud', c.get('lat'))), 'lon': float(c.get('longitud', c.get('lon'))),
                            't': s_.get('data', '')})
            except (TypeError, ValueError, AttributeError):
                continue
    return {'strikes': out[-2000:], 'source': 'Meteocat XDDE lightning, last 2 hours'}


def day_sky(hours: list, day_iso: str, code: int) -> str:
    """Daily icon: thunder if any hour of the day reaches the storm threshold, else the model's daily code."""
    if any(h.t.date().isoformat() == day_iso and h.storm >= E.STORM_ICON for h in hours):
        return 'storm'
    return E.sky_kind(code, False)


def now_sky(cur, observed: dict | None) -> str:
    """Current icon: thunder when Meteocat measured lightning within 10 km in the last two hours."""
    lt = (observed or {}).get('lightning') or {}
    return 'storm' if (lt.get('near') or 0) > 0 else cur.sky


def ratingword(r: int) -> str:
    return ['poor', 'poor', 'marginal', 'fair', 'good', 'epic'][max(0, min(5, r))]


def places(src, q: str) -> list[dict]:
    data = src.places(q) if len(q) >= 2 else {}
    out = []
    for r in data.get('results', []) or []:
        if r.get('admin1') not in ('Catalonia', 'Catalunya', 'Cataluña'):
            continue
        out.append({'name': r['name'], 'region': r.get('admin2') or r.get('admin3') or '',
                    'lat': round(r['latitude'], 4), 'lon': round(r['longitude'], 4)})
    return out[:10]


def reverse(src, lat: float, lon: float) -> dict:
    try:
        d = src.reverse(lat, lon)
        a = d.get('address', {})
        # Prefer the settlement; fall back to the feature name only when it isn't just the country.
        name = (a.get('town') or a.get('city') or a.get('village') or a.get('municipality') or a.get('suburb')
                or (d.get('name') if d.get('addresstype') not in ('country', 'state') else None))
    except Exception:
        name = None
    if not name:  # e.g. a blurred "approximate" location that lands in the sea: use the nearest town
        try:
            for f in src.reverse_nearest(lat, lon).get('features', []):
                pr = f.get('properties', {})
                name = pr.get('city') or pr.get('town') or pr.get('village') or pr.get('county')
                if name:
                    break
        except Exception:
            name = None
    return {'name': name or f'{lat:.2f}, {lon:.2f}', 'lat': lat, 'lon': lon}


def grid(src) -> dict:
    """Current wind/temperature/rain on a 0.3° grid over Catalonia (one Open-Meteo call, cached 30 min)."""
    lats, lons = [], []
    la = 40.55
    while la <= 42.85:
        lo = 0.2
        while lo <= 3.35:
            lats.append(round(la, 2))
            lons.append(round(lo, 2))
            lo += 0.3
        la += 0.3
    data = src.grid(lats, lons)
    pts = []
    for d in data if isinstance(data, list) else [data]:
        c = d.get('current', {})
        if c.get('wind_speed_10m') is None:
            continue
        pts.append({'lat': d['latitude'], 'lon': d['longitude'], 'wind': c['wind_speed_10m'],
                    'gust': c.get('wind_gusts_10m'), 'wdir': c['wind_direction_10m'], 'temp': c['temperature_2m'],
                    'precip': c.get('precipitation', 0)})
    t = (data[0] if isinstance(data, list) and data else {}).get('current', {}).get('time', '')
    return {'time': t[11:16], 'points': pts, 'source': 'Open-Meteo current conditions (model)'}


GRID_LATS = [round(40.5 + 0.25 * i, 2) for i in range(10)]   # south → north
GRID_LONS = [round(0.15 + 0.25 * j, 2) for j in range(14)]   # west → east


def grid_forecast(src, hours: int = 48) -> dict:
    """Hourly forecast on a regular 0.25° grid over Catalonia for the map timeline.

    fields[name][t][r * len(lons) + c] for time t, grid row r (lat) and column c (lon).
    """
    la = [a for a in GRID_LATS for _ in GRID_LONS]
    lo = [b for _ in GRID_LATS for b in GRID_LONS]
    data = src.grid_forecast(la, lo, hours)
    pts = data if isinstance(data, list) else [data]
    times = pts[0]['hourly']['time']
    keys = {'wind': 'wind_speed_10m', 'wdir': 'wind_direction_10m', 'gust': 'wind_gusts_10m', 'temp': 'temperature_2m',
            'precip': 'precipitation', 'pprob': 'precipitation_probability', 'code': 'weather_code'}
    fields = {}
    for name, k in keys.items():
        fields[name] = [[(round(v, 1) if isinstance(v, float) else (v if v is not None else 0))
                         for v in (p['hourly'][k][t] for p in pts)] for t in range(len(times))]
    # Thunderstorm risk per cell, the same estimate as the planners use (instability, showers, thunder codes).
    def risk(p, t):
        hh = p['hourly']
        return E.Hour(t=None, temp=0, feels=0, rh=0, precip=0, pprob=hh['precipitation_probability'][t] or 0,
                      code=int(hh['weather_code'][t] or 0), wind=0, wdir=0, gust=0, uv=0,
                      cape=(hh.get('cape') or [0] * len(times))[t] or 0, freezing=0, pressure=0, cloud=0,
                      daylight=True).storm
    fields['storm'] = [[risk(p, t) for p in pts] for t in range(len(times))]
    return {'lats': GRID_LATS, 'lons': GRID_LONS, 'times': times, 'fields': fields,
            'source': 'Open-Meteo hourly forecast (best-match models), 0.25° grid'}


SUMMARY = {'sun': 'Sunny', 'partly': 'Partly cloudy', 'cloud': 'Cloudy', 'rain': 'Rain', 'storm': 'Thunderstorms',
           'snow': 'Snow', 'fog': 'Fog', 'night': 'Clear'}
CHIPS = {'bike': {'label': 'Ride length', 'options': ['1 h', '2 h', '3 h', '4 h', '5 h'], 'selected': '3 h'},
         'run': {'label': 'Run length', 'options': ['5 km', '10 km', '15 km', '21 km'], 'selected': '10 km'}}
SOURCES = {
    'wing': 'Open-Meteo hourly forecast (wind, gusts), marine (chop, water temp), models and ECMWF ensemble; Meteocat (SMC): live XEMA wind, official warnings',
    'surf': 'Open-Meteo Marine (waves, swell period and direction, water temp), forecast (wind), wave models; Meteocat (SMC): live XEMA station, official warnings',
    'bike': 'Open-Meteo hourly forecast (rain, wind, temperature, UV), models and ensemble; Meteocat (SMC): live XEMA station, official warnings',
    'run': 'Open-Meteo hourly forecast (temperature, feels-like, UV, rain), models and ensemble; Meteocat (SMC): live XEMA station, official warnings',
    'hike': 'Open-Meteo forecast scaled to the summit (lapse rate), storm risk estimated from CAPE and showers, freezing level; Meteocat (SMC): live XEMA stations (Cadí Nord wind), official warnings',
}


def wetsuit(sst: float | None) -> str:
    if sst is None:
        return ''
    return 'shorty' if sst >= 22 else ('3/2 suit' if sst >= 18 else ('4/3 suit' if sst >= 15 else '5/4 + boots'))


def uv_word(uv: float) -> str:
    return 'low' if uv < 3 else ('moderate' if uv < 6 else ('high' if uv < 8 else 'very high'))


def last_light(hm: str) -> str:
    h, m = map(int, hm.split(':'))
    m += 28
    return f'{h + m // 60:02d}:{m % 60:02d}'


def road(h: E.Hour) -> str:
    return 'wet' if h.precip >= 0.3 or h.rain3h >= 1 else ('damp' if h.rain3h >= 0.1 else 'dry')


def layer(feels: float, p: dict) -> str:
    adj = {'Less': -2, 'Average': 0, 'More': 2}.get(p.get('cold', 'Average'), 0)
    t = feels - adj
    return 'tights + jacket' if t < 6 else ('long sleeve' if t < 13 else ('t-shirt' if t < 22 else 'vest'))


def tail_share(route: list, wind_from: float) -> int:
    import math
    tail = total = 0.0
    for a, b in zip(route, route[1:]):
        dx, dy = b[0] - a[0], a[1] - b[1]
        seg = math.hypot(dx, dy)
        bearing = (math.degrees(math.atan2(dx, dy)) + 360) % 360
        if math.cos(math.radians(bearing - (wind_from + 180))) > 0.35:
            tail += seg
        total += seg
    return round(100 * tail / total) if total else 0
