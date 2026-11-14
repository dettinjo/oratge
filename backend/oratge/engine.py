"""Hourly features and per-sport ratings (factors and weights from design/logic/planner-logic.json).

Each factor returns a score 0–1; an hour's rating = round(5 × Σ weight × score), with hard stops
(night for daylight sports, offshore wind for wing, storms above the user's limit for hikes).
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import date, datetime

from . import wingcalc as W

HOURS = list(range(7, 21))  # columns of every hour chart


def clamp01(x: float) -> float:
    return max(0.0, min(1.0, x))


def ramp(x: float, zero: float, one: float) -> float:
    """0 at `zero`, 1 at `one` (works in either direction)."""
    if one == zero:
        return 1.0 if x >= one else 0.0
    return clamp01((x - zero) / (one - zero))


def in_range(x: float, lo: float, hi: float, soft_lo: float, soft_hi: float) -> float:
    if lo <= x <= hi:
        return 1.0
    return ramp(x, lo - soft_lo, lo) if x < lo else ramp(x, hi + soft_hi, hi)


def angdiff(a: float, b: float) -> float:
    return abs((a - b + 180) % 360 - 180)


def shore_relation(wind_from: float, shore_facing: float) -> str:
    """Relation of a wind to a beach facing `shore_facing` (towards the sea)."""
    d = angdiff(wind_from, shore_facing)
    if d < 30:
        return 'on'
    if d < 70:
        return 'side-on'
    if d < 115:
        return 'side'
    return 'off'


STORM_ICON = 30  # % storm risk from which an hour shows the thunder icon


def sky_kind(code: int, night: bool) -> str:
    if code >= 95:
        return 'storm'
    if code in (71, 73, 75, 77, 85, 86):
        return 'snow'
    if code >= 51:
        return 'rain'
    if code in (45, 48):
        return 'fog'
    if code == 3:
        return 'cloud'
    if night:
        return 'night'
    return 'partly' if code in (1, 2) else 'sun'


@dataclass
class Hour:
    t: datetime
    temp: float
    feels: float
    rh: float
    precip: float
    pprob: float
    code: int
    wind: float
    wdir: float
    gust: float
    uv: float
    cape: float
    freezing: float
    pressure: float
    cloud: float
    daylight: bool
    wave: float | None = None
    wave_dir: float | None = None
    period: float | None = None
    swell: float | None = None
    swell_dir: float | None = None
    swell_period: float | None = None
    sst: float | None = None
    rain3h: float = 0.0

    @property
    def sky(self) -> str:
        # Thunder: the model's thunder codes, or our own storm risk (instability + showers) from 30 %.
        if self.storm >= STORM_ICON:
            return 'storm'
        return sky_kind(self.code, not self.daylight)

    @property
    def storm(self) -> float:
        """Storm risk %, estimated from CAPE, showers and thunder codes (Open-Meteo has no direct probability)."""
        # Instability only becomes thunder when showers form: weight CAPE by the precipitation chance.
        # (Before 2026-11-14: 0.35 + 0.65 × chance, which shaded dry, unstable days at 10–20 %.)
        # CAPE below ~150 J/kg is negligible; drizzle (codes 51–57) is not convective.
        base = min(75.0, max(0.0, self.cape - 150) / 14.0) * (0.1 + 0.9 * self.pprob / 100)
        if 51 <= self.code <= 57:
            base *= 0.6
        # The model's own codes set a floor that grows with the precipitation chance.
        if self.code >= 95:
            base = max(base, 40 + 30 * self.pprob / 100)
        elif self.code in (80, 81, 82):
            base = max(base, 10 + 20 * self.pprob / 100)
        return round(min(95.0, base))


def parse_hours(fc: dict, marine: dict | None = None) -> list[Hour]:
    h = fc['hourly']
    sun = {d[:10]: (r, s) for d, r, s in zip(fc['daily']['sunrise'], fc['daily']['sunrise'], fc['daily']['sunset'])}
    mh = marine['hourly'] if marine else None
    midx = {t: i for i, t in enumerate(mh['time'])} if mh else {}
    out: list[Hour] = []
    for i, ts in enumerate(h['time']):
        t = datetime.fromisoformat(ts)
        r, s = sun.get(ts[:10], (f'{ts[:10]}T07:30', f'{ts[:10]}T17:40'))
        daylight = r[11:] <= ts[11:] < s[11:] or (ts[11:13] == r[11:13])

        def g(k, d=0.0):
            v = h.get(k, [None] * (i + 1))[i]
            return d if v is None else float(v)

        hr = Hour(t=t, temp=g('temperature_2m'), feels=g('apparent_temperature'), rh=g('relative_humidity_2m'),
                  precip=g('precipitation'), pprob=g('precipitation_probability'), code=int(g('weather_code')),
                  wind=g('wind_speed_10m'), wdir=g('wind_direction_10m'), gust=g('wind_gusts_10m'),
                  uv=g('uv_index'), cape=g('cape'), freezing=g('freezing_level_height', 3000),
                  pressure=g('pressure_msl', 1013), cloud=g('cloud_cover'), daylight=daylight)
        if mh and ts in midx:
            j = midx[ts]

            def m(k):
                v = mh.get(k, [None] * (j + 1))[j]
                return None if v is None else float(v)

            hr.wave, hr.wave_dir, hr.period = m('wave_height'), m('wave_direction'), m('wave_period')
            hr.swell, hr.swell_dir, hr.swell_period = m('swell_wave_height'), m('swell_wave_direction'), m('swell_wave_period')
            hr.sst = m('sea_surface_temperature')
        hr.rain3h = sum(o.precip for o in out[-3:])
        out.append(hr)
    return out


def day_hours(hours: list[Hour], day: date) -> list[Hour]:
    by = {(x.t.date(), x.t.hour): x for x in hours}
    return [by[(day, hh)] for hh in HOURS if (day, hh) in by]


# ── profile defaults (same as the app's sample profile) ──
DEFAULT_PROFILE = {
    'windFrom': 14, 'windTo': 24, 'gustLimit': 26, 'directions': ['Onshore', 'Side-on', 'Side'],
    'waveFrom': 0.6, 'waveTo': 1.8, 'minPeriod': 8,
    'maxWindBike': 20, 'mudguards': False, 'lights': True,
    'comfortFrom': 5, 'comfortTo': 22, 'lightRainOk': True,
    'maxStorm': 20, 'maxSummitWind': 30, 'crampons': True, 'weight': 78, 'cold': 'Average',
}


@dataclass
class Factor:
    name: str
    accent: str
    weight: int
    score: float
    observed: str


@dataclass
class Rated:
    hour: Hour
    rating: int
    factors: list[Factor] = field(default_factory=list)
    total: float = 0.0


WEIGHTS = {
    'wing': [('Wind in range', 'wind', 25), ('Your gear', 'wind', 15), ('Gust factor', 'wind', 15), ('Direction', 'wind', 20),
             ('Chop', 'water', 10), ('Rain', 'water', 5), ('Daylight', 'sun', 10)],
    'surf': [('Swell height', 'water', 30), ('Period', 'water', 25), ('Wind vs shore', 'wind', 25),
             ('Swell direction', 'water', 10), ('Daylight', 'sun', 10)],
    'bike': [('Dry window', 'water', 35), ('Wind', 'wind', 20), ('Temperature', 'heat', 20), ('Roads', 'water', 15),
             ('UV', 'sun', 10)],
    'run': [('Temperature', 'heat', 35), ('Feels like', 'heat', 15), ('Wind', 'wind', 20), ('Rain', 'water', 20),
            ('UV', 'sun', 10)],
    'hike': [('Storm risk', 'storm', 35), ('Summit wind', 'wind', 20), ('Cold', 'snow', 15),
             ('Visibility', 'sun', 15), ('Daylight', 'sun', 15)],
}

DIR_NAMES = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']


def compass(deg: float) -> str:
    return DIR_NAMES[int(((deg % 360) + 22.5) // 45) % 8]


def rate(sport: str, h: Hour, spot: dict, p: dict) -> Rated:
    f = float
    if sport == 'wing':
        rel = shore_relation(h.wdir, spot.get('shore_facing', 180))
        allowed = {'on': 'Onshore', 'side-on': 'Side-on', 'side': 'Side', 'off': 'Offshore'}[rel] in p['directions']
        gf = h.gust / h.wind if h.wind > 1 else 1.0
        g = W.gear(p)
        fit = W.pick(g, h.wind, h.gust)
        scores = [in_range(h.wind, f(p['windFrom']), f(p['windTo']), 4, 6) * (0 if h.gust > f(p['gustLimit']) + 4 else 1),
                  W.score(g, h.wind, h.gust),
                  ramp(gf, 1.8, 1.3), {'side-on': 1.0, 'side': 0.9, 'on': 0.7, 'off': 0.0}[rel] if allowed else 0.0,
                  ramp(h.wave or 0, 1.5, 0.5), 1 - h.pprob / 100, 1.0 if h.daylight else 0.0]
        obs = [f'{h.wind:.0f} kn vs your {p["windFrom"]}–{p["windTo"]}',
               f'{fit["text"]} · quiver works {g["min_wind"]:.0f}–{g["max_gust"]:.0f} kn',
               f'gusts × {gf:.2f}', f'{rel} {compass(h.wdir)}',
               f'{(h.wave or 0):.1f} m', f'{h.pprob:.0f} %', 'day' if h.daylight else 'dark']
        if h.wind < g['min_wind'] - 2:
            cap = 2  # even the biggest wing won't get you foiling
        stop = rel == 'off' or not h.daylight
    elif sport == 'surf':
        rel = shore_relation(h.wdir, spot.get('shore_facing', 180))
        height = h.swell if h.swell is not None else (h.wave or 0)
        period = h.swell_period or h.period or 0
        exp = spot.get('exposure', [0, 360])
        sdir = h.swell_dir if h.swell_dir is not None else (h.wave_dir or 0)
        inside = (sdir - exp[0]) % 360 <= (exp[1] - exp[0]) % 360
        wind_score = 1.0 if rel == 'off' else (0.9 if h.wind < 6 else (0.6 if rel in ('side', 'side-on') else ramp(h.wind, 15, 4) * 0.6))
        scores = [in_range(height, f(p['waveFrom']), f(p['waveTo']), 0.4, 0.8), ramp(period, f(p['minPeriod']) - 3, f(p['minPeriod']) + 2),
                  wind_score, 1.0 if inside else 0.2, 1.0 if h.daylight else 0.0]
        obs = [f'{height:.1f} m', f'{period:.0f} s', f'{rel} {compass(h.wdir)} {h.wind:.0f} kn',
               f'{compass(sdir)}, {"inside" if inside else "outside"} {exp[0]}–{exp[1]}°', 'day' if h.daylight else 'dark']
        stop = not h.daylight
        flat = height < f(p['waveFrom']) * 0.6
        short = period < f(p['minPeriod']) - 2
        cap = 1 if (flat and short) else (2 if (flat or short) else 5)
    elif sport == 'bike':
        dry = 1 - h.pprob / 100 if h.precip < 0.2 else 0.15
        roads = 1.0 if h.rain3h < 0.1 else (0.6 if h.rain3h < 1 else 0.25)
        if not p.get('mudguards') and h.rain3h >= 0.1:
            roads *= 0.8
        scores = [dry, ramp(max(h.wind, h.gust * 0.7), f(p['maxWindBike']) + 5, f(p['maxWindBike']) * 0.6),
                  in_range(h.temp, 10, 26, 8, 8), roads, ramp(h.uv, 9, 5)]
        obs = [f'{h.pprob:.0f} % · {h.precip:.1f} mm', f'{compass(h.wdir)} {h.wind:.0f} kn', f'{h.temp:.0f}°',
               'dry' if roads == 1 else f'{h.rain3h:.1f} mm in 3 h', f'{h.uv:.0f}']
        stop = not h.daylight and not p.get('lights')
    elif sport == 'run':
        lo, hi = f(p['comfortFrom']), f(p['comfortTo'])
        rain_ok = 0.6 if p.get('lightRainOk') else 0.2
        scores = [in_range(h.temp, lo, hi, 6, 6), in_range(h.feels, lo, hi, 6, 6), ramp(h.wind, 22, 10),
                  1.0 if h.precip < 0.1 else (rain_ok if h.precip < 1 else 0.0), ramp(h.uv, 8, 4)]
        obs = [f'{h.temp:.0f}°', f'{h.feels:.0f}°', f'{h.wind:.0f} kn', f'{h.pprob:.0f} %', f'{h.uv:.0f}']
        stop = False
    else:  # hike (values at summit elevation)
        ms = f(p['maxStorm'])
        scores = [ramp(h.storm, ms + 40, ms), ramp(h.gust, f(p['maxSummitWind']) + 10, f(p['maxSummitWind']) * 0.7),
                  ramp(h.temp, -8, 2), ramp(h.cloud, 100, 50) * (0.4 if h.code in (45, 48) else 1),
                  1.0 if h.daylight else 0.0]
        obs = [f'{h.storm:.0f} %', f'{h.wind:.0f} kn, gusts {h.gust:.0f}', f'{h.temp:.0f}°',
               'clear' if h.cloud < 50 else f'{h.cloud:.0f} % cloud', 'day' if h.daylight else 'dark']
        stop = not h.daylight or h.storm > ms + 30
    factors = [Factor(n, a, w, round(s, 2), o) for (n, a, w), s, o in zip(WEIGHTS[sport], scores, obs)]
    cap = locals().get('cap', 5)
    total = 5 * sum(fa.weight / 100 * fa.score for fa in factors)
    rating = 0 if stop else max(1, min(cap, round(total)))
    if sport == 'wing' and rating and h.wind < f(p['windFrom']) - 4:
        rating = 1
    return Rated(h, rating, factors, round(total, 1))


def best_window(rated: list[Rated], length: int | None = None) -> tuple[int, int, int] | None:
    """(start_hour, end_hour_exclusive, peak_rating) of the best window, or None.

    With `length` (ride/run duration in hours) the window is the block of that length with the best
    average score. Otherwise it is the contiguous run around the best hour whose score stays within
    0.6 points of the peak (and at rating ≥ 2).
    """
    if not rated or max(r.rating for r in rated) < 2:
        return None
    if length:
        best = None
        for i in range(0, len(rated) - length + 1):
            blk = rated[i:i + length]
            if min(r.rating for r in blk) == 0:
                continue
            avg = sum(r.total for r in blk) / length
            if best is None or avg > best[0]:
                best = (avg, blk)
        if not best:
            return None
        blk = best[1]
        return blk[0].hour.t.hour, blk[-1].hour.t.hour + 1, round(min(5, max(1, sum(r.rating for r in blk) / length)))
    k = max(range(len(rated)), key=lambda i: (rated[i].rating, rated[i].total))
    top = rated[k]
    ok = lambda r: r.rating >= 2 and r.total >= top.total - 0.6  # noqa: E731
    a = b = k
    while a > 0 and ok(rated[a - 1]):
        a -= 1
    while b < len(rated) - 1 and ok(rated[b + 1]):
        b += 1
    # Keep at most 5 hours, trimming the weaker end first, so "best" stays a real window.
    while b - a + 1 > 5:
        if rated[a].total < rated[b].total or (rated[a].total == rated[b].total and k - a > b - k):
            a += 1
        else:
            b -= 1
    return rated[a].hour.t.hour, rated[b].hour.t.hour + 1, top.rating


def percentile(values: list[float], q: float) -> float:
    s = sorted(v for v in values if v is not None)
    if not s:
        return 0.0
    k = (len(s) - 1) * q
    lo, hi = math.floor(k), math.ceil(k)
    return s[lo] + (s[hi] - s[lo]) * (k - lo)
