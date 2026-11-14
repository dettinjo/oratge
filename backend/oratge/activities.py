"""Activities the user wants checked: a sport at a place ("spot") or a GPX route.

- custom_spot / shore_facing: turn a user's place into a spot the rating engine understands.
- check: best window per day for each spot activity (home screen and notifications).
- route: weather along a GPX track at the time you'd be at each point — where and when it rains,
  head/tailwind, temperature, thunder — plus the best start time that day.
"""
from __future__ import annotations

import math
from datetime import date, datetime, timedelta

from . import engine as E
from .meteocat import km

SPORTS = ('wing', 'surf', 'bike', 'run', 'hike')


def bearing(lat1, lon1, lat2, lon2) -> float:
    p = math.pi / 180
    y = math.sin((lon2 - lon1) * p) * math.cos(lat2 * p)
    x = math.cos(lat1 * p) * math.sin(lat2 * p) - math.sin(lat1 * p) * math.cos(lat2 * p) * math.cos((lon2 - lon1) * p)
    return (math.atan2(y, x) / p + 360) % 360


def shore_facing(src, lat: float, lon: float) -> dict:
    """Which way the beach faces (towards the sea), from terrain elevation on two rings around the point."""
    dirs = list(range(0, 360, 15))
    lats, lons = [], []
    for r in (0.8, 2.0):
        for d in dirs:
            lats.append(lat + r / 111 * math.cos(math.radians(d)))
            lons.append(lon + r / (111 * math.cos(math.radians(lat))) * math.sin(math.radians(d)))
    elev = (src.elevation(lats, lons) or {}).get('elevation') or []
    sea = [dirs[i % len(dirs)] for i, e in enumerate(elev) if e is not None and e <= 0.5]
    if not sea:
        return {'facing': None, 'sea': 0.0}
    x = sum(math.sin(math.radians(d)) for d in sea)
    y = sum(math.cos(math.radians(d)) for d in sea)
    return {'facing': round((math.degrees(math.atan2(x, y)) + 360) % 360), 'sea': round(len(sea) / len(elev), 2)}


def custom_spot(sport: str, lat: float, lon: float, name: str, facing: float | None = None) -> dict:
    spot = {'id': 'custom', 'name': name, 'sport': sport, 'lat': lat, 'lon': lon, 'custom': True}
    if sport in ('wing', 'surf'):
        f = 180.0 if facing is None else float(facing)
        spot['shore_facing'] = f
        spot['exposure'] = [(f - 80) % 360, (f + 80) % 360]
    return spot


def check(make_builder, items: list[dict], days: int = 3) -> list[dict]:
    """For each spot activity: best window and rating for today and the next days."""
    from .build import WD, today_local, win  # local import: build imports this module's helpers lazily
    out = []
    t0 = today_local()
    for a in items[:20]:
        sport = a.get('sport')
        if sport not in SPORTS or a.get('lat') is None or a.get('lon') is None:
            continue
        spot = custom_spot(sport, float(a['lat']), float(a['lon']), a.get('name') or sport, a.get('facing'))
        b = make_builder(spot)
        try:
            hours = b.hours(spot, summit=False)
        except Exception as e:  # one failing place must not hide the others
            out.append({'id': a.get('id'), 'error': str(e)[:80], 'days': []})
            continue
        rows = []
        for i in range(days):
            day = t0 + timedelta(days=i)
            rated = [E.rate(sport, h, spot, b.p) for h in E.day_hours(hours, day)]
            w = E.best_window(rated, b.length(sport))
            ended = i == 0 and w is not None and w[1] <= datetime.now().hour
            rows.append({'day': 'Today' if i == 0 else ('Tomorrow' if i == 1 else WD[day.weekday()]), 'date': str(day),
                         'rating': w[2] if w and not ended else 0,
                         'window': win(w) if w and not ended else '—',
                         'reason': b.reason(sport, rated, w) if rated else ''})
        out.append({'id': a.get('id'), 'sport': sport, 'name': spot['name'], 'days': rows})
    return out


# ── GPX routes ──

def resample(points: list[list[float]], max_samples: int = 48) -> list[dict]:
    """Points every ~2 km (at most [max_samples]) with cumulative distance and travel bearing."""
    pts = [p for p in points if len(p) >= 2]
    if len(pts) < 2:
        return []
    cum = [0.0]
    for a, b in zip(pts, pts[1:]):
        cum.append(cum[-1] + km(a[0], a[1], b[0], b[1]))
    total = cum[-1]
    step = max(1.0, total / (max_samples - 1)) if total > 0 else 1
    out, target, j = [], 0.0, 0
    while target <= total + 1e-9 and len(out) < max_samples:
        while j < len(cum) - 2 and cum[j + 1] < target:
            j += 1
        a, b = pts[j], pts[j + 1]
        seg = cum[j + 1] - cum[j]
        f = 0 if seg == 0 else (target - cum[j]) / seg
        lat, lon = a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f
        ele = None
        if len(a) > 2 and len(b) > 2 and a[2] is not None and b[2] is not None:
            ele = a[2] + (b[2] - a[2]) * f
        out.append({'km': round(target, 2), 'lat': lat, 'lon': lon, 'ele': ele, 'bearing': bearing(a[0], a[1], b[0], b[1])})
        target += step
    if out[-1]['km'] < total - 0.3 or len(out) == 1:
        a, b = pts[-2], pts[-1]
        out.append({'km': round(total, 2), 'lat': b[0], 'lon': b[1], 'ele': b[2] if len(b) > 2 else None,
                    'bearing': bearing(a[0], a[1], b[0], b[1])})
    return out


def timing(samples: list[dict], sport: str, p: dict, speed: float | None) -> list[float]:
    """Hours from the start at each sample. Bike: speed on the flat + 1 h per 800 m climbed;
    run: pace + 1 h per 600 m; hike: Naismith-style 4.5 km/h (or given) + climbing pace from the profile."""
    flat = speed or {'bike': float(p.get('rideSpeed') or 24), 'run': 60 / _pace_min(p.get('runPace')), 'hike': 4.5}.get(sport, 15)
    climb = {'bike': 800.0, 'run': 600.0, 'hike': float(p.get('climbPace') or 400)}.get(sport, 800.0)
    t, out = 0.0, [0.0]
    for a, b in zip(samples, samples[1:]):
        up = max(0.0, (b['ele'] or 0) - (a['ele'] or 0)) if a['ele'] is not None and b['ele'] is not None else 0.0
        t += (b['km'] - a['km']) / flat + up / climb
        out.append(t)
    return out


def _pace_min(pace) -> float:
    try:
        m, s = str(pace or '5:30').split(':')
        return int(m) + int(s) / 60
    except ValueError:
        return 5.5


def route(src, p: dict, points: list[list[float]], sport: str, start: datetime, speed: float | None = None) -> dict:
    samples = resample(points)
    if len(samples) < 2:
        raise ValueError('the track needs at least two points')
    if any(s['ele'] is None for s in samples):
        el = (src.elevation([s['lat'] for s in samples], [s['lon'] for s in samples]) or {}).get('elevation') or []
        for s, e in zip(samples, el):
            if s['ele'] is None:
                s['ele'] = e
    data = src.route_forecast([s['lat'] for s in samples], [s['lon'] for s in samples])
    fcs = data if isinstance(data, list) else [data]
    times = [datetime.fromisoformat(t) for t in fcs[0]['hourly']['time']]

    def weather_at(i: int, when: datetime) -> dict | None:
        h = fcs[min(i, len(fcs) - 1)]['hourly']
        k = min(range(len(times)), key=lambda j: abs((times[j] - when).total_seconds()))
        if abs((times[k] - when).total_seconds()) > 5400:
            return None
        g = lambda name, d=0: h.get(name, [d] * len(times))[k] if h.get(name, [d] * len(times))[k] is not None else d  # noqa: E731
        return {'temp': g('temperature_2m'), 'feels': g('apparent_temperature'), 'precip': g('precipitation'),
                'pprob': g('precipitation_probability'), 'code': int(g('weather_code')), 'wind': g('wind_speed_10m'),
                'wdir': g('wind_direction_10m'), 'gust': g('wind_gusts_10m'), 'cape': g('cape'), 'day': bool(g('is_day', 1))}

    offsets = timing(samples, sport, p, speed)

    def run(at: datetime) -> list[dict]:
        rows = []
        for i, (s, off) in enumerate(zip(samples, offsets)):
            when = at + timedelta(hours=off)
            w = weather_at(i, when)
            if w is None:
                rows.append({**s, 'eta': when.strftime('%H:%M'), 'missing': True})
                continue
            hr = E.Hour(t=when, temp=w['temp'], feels=w['feels'], rh=0, precip=w['precip'], pprob=w['pprob'], code=w['code'],
                        wind=w['wind'], wdir=w['wdir'], gust=w['gust'], uv=0, cape=w['cape'], freezing=3000, pressure=1013,
                        cloud=0, daylight=w['day'])
            # Head (+) or tail (−) wind along the direction of travel.
            head = w['wind'] * math.cos(math.radians(E.angdiff(w['wdir'], s['bearing'])))
            rows.append({'km': s['km'], 'lat': round(s['lat'], 5), 'lon': round(s['lon'], 5),
                         'ele': None if s['ele'] is None else round(s['ele']), 'eta': when.strftime('%H:%M'), 'at': when.isoformat(),
                         'temp': round(w['temp'], 1), 'feels': round(w['feels'], 1), 'precip': round(w['precip'], 1),
                         'pprob': round(w['pprob']), 'wind': round(w['wind'], 1), 'gust': round(w['gust'], 1),
                         'wdir': round(w['wdir']), 'head': round(head, 1), 'storm': hr.storm, 'sky': hr.sky, 'day': w['day']})
        return rows

    def score(rows: list[dict]) -> float:
        ok = [r for r in rows if not r.get('missing')]
        if not ok:
            return -1e9
        n = len(ok)
        wet = sum(1 for r in ok if r['precip'] >= 0.2 or r['pprob'] >= 60) / n
        head = sum(max(0, r['head']) for r in ok) / n
        storm = max(r['storm'] for r in ok)
        dark = sum(1 for r in ok if not r['day']) / n
        return -(wet * 60 + head * 1.5 + max(0, storm - 20) + dark * 80)

    rows = run(start)
    # Best start the same day, 06:00–18:00 (same forecast, re-timed).
    options = []
    for hh in range(6, 19):
        at = start.replace(hour=hh, minute=0)
        options.append((score(run(at)), hh))
    best = max(options) if options else None
    return {'samples': rows, 'summary': summarise(rows, sport), 'start': start.isoformat(timespec='minutes'),
            'duration_h': round(offsets[-1], 2), 'distance_km': samples[-1]['km'],
            'ascent_m': round(sum(max(0, (b['ele'] or 0) - (a['ele'] or 0)) for a, b in zip(samples, samples[1:]))),
            'best_start': None if not best else f'{best[1]:02d}:00',
            'start_options': [{'start': f'{hh:02d}:00', 'score': round(sc, 1)} for sc, hh in options]}


def summarise(rows: list[dict], sport: str) -> dict:
    ok = [r for r in rows if not r.get('missing')]
    if not ok:
        return {'lines': ['No forecast for that time yet (forecasts reach 7 days).'], 'rain': [], 'rating': 0}

    def spans(pred) -> list[dict]:
        out, cur = [], None
        for r in ok:
            if pred(r):
                cur = cur or {'from_km': r['km'], 'from': r['eta'], 'max_mm': 0.0, 'max_pct': 0}
                cur.update(to_km=r['km'], to=r['eta'])
                cur['max_mm'] = max(cur['max_mm'], r['precip'])
                cur['max_pct'] = max(cur['max_pct'], r['pprob'])
            elif cur:
                out.append(cur)
                cur = None
        if cur:
            out.append(cur)
        return out

    rain = spans(lambda r: r['precip'] >= 0.2 or r['pprob'] >= 60)
    maybe = spans(lambda r: 30 <= r['pprob'] < 60 and r['precip'] < 0.2)
    headwind = spans(lambda r: r['head'] >= 6)
    storms = [r for r in ok if r['storm'] >= E.STORM_ICON]
    lines = []
    if rain:
        for s in rain[:3]:
            lines.append(f'Rain km {s["from_km"]:.0f}–{s["to_km"]:.0f} ({s["from"]}–{s["to"]}), up to {s["max_mm"]:.1f} mm/h, {s["max_pct"]} %')
    elif maybe:
        lines.append(f'Mostly dry; showers possible km {maybe[0]["from_km"]:.0f}–{maybe[0]["to_km"]:.0f} ({maybe[0]["from"]}–{maybe[0]["to"]})')
    else:
        lines.append('Dry the whole way')
    if storms:
        lines.append(f'Thunder possible from km {storms[0]["km"]:.0f} ({storms[0]["eta"]}), up to {max(r["storm"] for r in storms)} %')
    if headwind:
        h = max(headwind, key=lambda s: s['to_km'] - s['from_km'])
        lines.append(f'Headwind km {h["from_km"]:.0f}–{h["to_km"]:.0f} ({h["from"]}–{h["to"]})')
    tail = sum(1 for r in ok if r['head'] <= -4) / len(ok)
    if tail >= 0.3:
        lines.append(f'Tailwind for {round(tail * 100)} % of the way')
    lo, hi = min(r['feels'] for r in ok), max(r['feels'] for r in ok)
    lines.append(f'Feels {lo:.0f}–{hi:.0f}°')
    dark = [r for r in ok if not r['day']]
    if dark:
        lines.append(f'Dark from km {dark[0]["km"]:.0f} ({dark[0]["eta"]})')
    wet_share = sum(1 for r in ok if r['precip'] >= 0.2 or r['pprob'] >= 60) / len(ok)
    rating = 5 - round(wet_share * 3) - (1 if storms else 0) - (1 if headwind and sport == 'bike' else 0) - (1 if dark else 0)
    return {'lines': lines, 'rain': rain, 'maybe': maybe, 'headwind': headwind, 'rating': max(1, min(5, rating)),
            'dry': not rain}
