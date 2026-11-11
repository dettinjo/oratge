"""Forecast/observation archive behind the planners' "station check".

- Every morning: snapshot the day's hourly forecast per spot (Open-Meteo; no key needed).
- Every night (Meteocat key only): store yesterday's XEMA readings for each spot's station, plus its wind station
  where the own one has no anemometer (1 call/station/day).
- Station check = last 30 days where both exist: bias, mean absolute error, and rating hit rate (±1).
"""
from __future__ import annotations

import logging
import threading
import time
from datetime import date, datetime, timedelta

from . import engine as E
from .spots import SPORT_SPOT, SPOTS, merge_wind

log = logging.getLogger('oratge')
MS_TO_KN = 1.94384
# The quantity each sport's check compares (forecast field, XEMA variable code, unit, scale).
CHECK = {'wing': ('wind', 30, 'kn', MS_TO_KN), 'hike': ('wind', 30, 'kn', MS_TO_KN), 'surf': ('wind', 30, 'kn', MS_TO_KN),
         'bike': ('temp', 32, '°', 1.0), 'run': ('temp', 32, '°', 1.0)}


def snapshot_forecasts(builder, day: date) -> int:
    n = 0
    for sport, sid in SPORT_SPOT.items():
        spot = SPOTS[sid]
        try:
            hours = builder.hours(spot, summit=sport == 'hike')
        except Exception as e:
            log.warning('archive forecast %s failed: %s', sid, e)
            continue
        for h in E.day_hours(hours, day):
            builder.src.store.archive('fc', sid, h.t.strftime('%Y-%m-%dT%H:00'),
                                      {'wind': h.wind, 'gust': h.gust, 'temp': h.temp, 'wdir': h.wdir,
                                       'rating': E.rate(sport, h, spot, builder.p).rating})
            n += 1
    return n


def store_observations(builder, day: date) -> int:
    """Yesterday's XEMA readings per station (needs METEOCAT_API_KEY)."""
    if not builder.src.meteocat_available():
        return 0
    n = 0
    for sid, spot in SPOTS.items():
        st = spot.get('station')
        if not st:
            continue
        def read(code):
            data = builder.src.try_meteocat('xema', f'/xema/v1/estacions/mesurades/{code}/{day:%Y/%m/%d}', 7 * 86400)
            return {v['codi']: v.get('lectures', []) for v in data[0]['variables']} if data else {}

        try:
            vars_ = read(st)
            if 30 not in vars_ and spot.get('wind_station'):
                vars_ = merge_wind(vars_, read(spot['wind_station']))
            per_hour: dict[str, dict] = {}
            for codi, lectures in vars_.items():
                for lec in lectures:
                    ts = lec['data'][:13] + ':00'  # 30-min readings → keep the one on the hour
                    if lec['data'][14:16] != '00':
                        continue
                    per_hour.setdefault(ts, {})[codi] = float(lec['valor'])
            for ts, vals in per_hour.items():
                builder.src.store.archive('obs', sid, ts, vals)
                n += 1
        except Exception as e:
            log.info('obs parse %s failed: %s', sid, e)
    return n


def station_check(store, sport: str, sid: str, today: date, rate_obs=None) -> dict | None:
    field, code, unit, scale = CHECK[sport]
    since = str(today - timedelta(days=30))
    fc = dict(store.archived('fc', sid, since))
    obs = dict(store.archived('obs', sid, since))
    key = str(code)  # JSON round-trip turns variable codes into strings
    pairs = [(ts, fc[ts][field], float(obs[ts][key]) * scale) for ts in sorted(fc) if ts in obs and key in obs[ts]]
    days = {ts[:10] for ts, *_ in pairs}
    if len(days) < 7:
        return None
    diffs = [o - f for _, f, o in pairs]
    bias = sum(diffs) / len(diffs)
    mae = sum(abs(d) for d in diffs) / len(diffs)
    hits = [abs(fc[ts]['rating'] - rate_obs(ts, o)) <= 1 for ts, _, o in pairs] if rate_obs else []
    yday = str(today - timedelta(days=1))
    y = [(f, o) for ts, f, o in pairs if ts.startswith(yday)] or [(f, o) for _, f, o in pairs[-12:]]
    spot = SPOTS[sid]
    sign = '+' if bias >= 0 else '−'
    return {
        'title': f'Station check · {spot.get("station_name", sid)}',
        'trend': {'accent': 'wind' if unit == 'kn' else 'heat', 'values': [round(o, 1) for _, o in y],
                  'compare': [round(f, 1) for f, _ in y], 'nowIndex': len(y) - 1, 'nowLabel': f'{y[-1][1]:.0f}',
                  'caption': ['yesterday', 'now'], 'height': 90},
        'legend': 'solid: measured at the station   dashed: the forecast for the same hours',
        'note': (f'Over {len(days)} days the forecast ran {abs(bias):.1f} {unit} {"low" if bias > 0 else "high"} at this station.'),
        'tiles': [{'label': 'Bias', 'value': f'{sign}{abs(bias):.1f} {unit}', 'sub': 'models too low' if bias > 0 else 'models too high',
                   'accent': 'wind' if unit == 'kn' else 'heat'},
                  {'label': 'Error', 'value': f'{mae:.1f} {unit}', 'sub': f'mean, {len(days)} days'},
                  {'label': 'Hit rate', 'value': f'{round(100 * sum(hits) / len(hits))} %' if hits else '—', 'sub': 'rating ±1'}],
    }


def start_scheduler(make_builder, every_s: int = 3600):
    """Hourly loop: morning forecast snapshot, nightly observations. Idempotent (insert or replace)."""
    def loop():
        done_fc, done_obs = None, None
        while True:
            try:
                now = datetime.now()
                b = make_builder()
                if now.hour >= 6 and done_fc != now.date():
                    log.info('archived %d forecast hours', snapshot_forecasts(b, now.date()))
                    done_fc = now.date()
                if now.hour >= 2 and done_obs != now.date():
                    if b.src.meteocat_available():
                        try:
                            log.info('meteocat quota synced: %s', b.src.sync_quota())
                        except Exception as e:
                            log.warning('quota sync failed: %s', e)
                    log.info('archived %d observations', store_observations(b, now.date() - timedelta(days=1)))
                    done_obs = now.date()
            except Exception as e:
                log.warning('archive loop: %s', e)
            time.sleep(every_s)
    t = threading.Thread(target=loop, daemon=True, name='oratge-archive')
    t.start()
    return t
