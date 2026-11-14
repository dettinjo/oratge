"""Oratge backend API. All responses use the app's JSON contract (see app/lib/data/models.dart).

Planner/summary requests may carry the user's ranges as query parameters; they are used for the
rating and never stored.
"""
import json
from datetime import datetime
import logging
import time

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

import os

from .archive import start_scheduler
from . import activities as A
from . import build as build_mod
from .build import Builder
from .config import settings
from .sources import Sources
from .spots import HOME, SPORT_SPOT, SPOTS
from .store import Store

logging.basicConfig(level=logging.INFO)
app = FastAPI(title='Oratge', version='0.1.0')
# Read-only API protected by a bearer token; the web build may run on another origin.
app.add_middleware(GZipMiddleware, minimum_size=2000)
app.add_middleware(CORSMiddleware, allow_origins=['*'], allow_methods=['GET', 'PUT', 'POST'], allow_headers=['Authorization', 'Content-Type'])
_store = Store(settings.db_path)
_sources = Sources(_store)

PROFILE_KEYS = {'windFrom', 'windTo', 'gustLimit', 'waveFrom', 'waveTo', 'minPeriod', 'maxWindBike', 'comfortFrom',
                'comfortTo', 'maxStorm', 'maxSummitWind', 'weight', 'climbPace', 'daylightMargin', 'runDistance',
                'boardVolume', 'frontWing', 'rideSpeed'}
PROFILE_FLAGS = {'mudguards', 'lights', 'lightRainOk', 'crampons'}


def auth(authorization: str | None = Header(default=None)):
    if settings.app_token and authorization != f'Bearer {settings.app_token}':
        raise HTTPException(401, 'missing or wrong token')


def builder(request: Request) -> Builder:
    q = request.query_params
    p = {}
    for k in PROFILE_KEYS:
        try:
            if k in q:
                p[k] = float(q[k])
        except ValueError:
            pass  # ignore malformed numbers; defaults apply
    p.update({k: q[k] in ('1', 'true') for k in PROFILE_FLAGS if k in q})
    if 'directions' in q:
        p['directions'] = q['directions'].split(',')
    if 'cold' in q:
        p['cold'] = q['cold']
    if 'wings' in q:
        p['wings'] = q['wings'].split(',')
    if 'wingLevel' in q:
        p['wingLevel'] = q['wingLevel']
    if 'runPace' in q:
        p['runPace'] = q['runPace']
    return Builder(_sources, p)


@app.on_event('startup')
def _archive():
    if os.environ.get('ORATGE_ARCHIVE', '1') == '1':
        start_scheduler(lambda: Builder(_sources))


@app.get('/health')
def health():
    return {'ok': True, 'meteocat': bool(settings.meteocat_key),
            'quota': {plan: {'used': _store.used(plan), 'limit': lim, 'today_left': _sources.allowance(plan)}
                      for plan, lim in settings.quota.items()}}


@app.get('/v1/today', dependencies=[Depends(auth)])
def today(lat: float | None = None, lon: float | None = None, place: str | None = None, b: Builder = Depends(builder)):
    if lat is not None and lon is not None:
        if not (40.0 <= lat <= 43.5 and -0.5 <= lon <= 3.6):
            raise HTTPException(400, 'Oratge covers Catalonia')
        return b.today({'name': place or f'{lat:.2f}, {lon:.2f}', 'lat': lat, 'lon': lon})
    return b.today()


@app.get('/v1/hourly', dependencies=[Depends(auth)])
def hourly(lat: float | None = None, lon: float | None = None, place: str | None = None, b: Builder = Depends(builder)):
    if lat is not None and lon is not None and not (40.0 <= lat <= 43.5 and -0.5 <= lon <= 3.6):
        raise HTTPException(422, 'Oratge covers Catalonia only')
    p = HOME if lat is None or lon is None else {'name': place or f'{lat:.2f}, {lon:.2f}', 'lat': lat, 'lon': lon}
    return build_mod.hourly(b, p)


@app.get('/v1/alerts', dependencies=[Depends(auth)])
def alerts(sports: str | None = None, lat: float | None = None, lon: float | None = None, place: str | None = None,
           v: int = 1, b: Builder = Depends(builder)):
    """v=2 (app 0.8+) filters on the device with the user's notification settings. Older apps notified about
    everything, so they only get the defaults: severe (orange/red) warnings and good wing foil windows."""
    p = None if lat is None or lon is None else {'name': place or f'{lat:.2f}, {lon:.2f}', 'lat': lat, 'lon': lon}
    out = b.alerts(sports.split(',') if sports else None, p)
    if v < 2:
        out['alerts'] = [a for a in out['alerts']
                         if (a['kind'] == 'window' and a.get('sport') == 'wing')
                         or (a['kind'] == 'warning' and a.get('level') in ('orange', 'red'))]
        out['ratings'] = {k: r for k, r in out['ratings'].items() if r['sport'] == 'wing'}
    return out


@app.get('/v1/map/lightning', dependencies=[Depends(auth)])
def map_lightning(b: Builder = Depends(builder)):
    return build_mod.map_lightning(b)


@app.get('/v1/places', dependencies=[Depends(auth)])
def places(q: str = ''):
    return {'places': build_mod.places(_sources, q.strip())}


@app.get('/v1/reverse', dependencies=[Depends(auth)])
def reverse(lat: float, lon: float):
    return build_mod.reverse(_sources, lat, lon)


@app.get('/v1/map/forecast', dependencies=[Depends(auth)])
def map_forecast(hours: int = 48):
    return build_mod.grid_forecast(_sources, max(6, min(hours, 72)))


@app.get('/v1/map/grid', dependencies=[Depends(auth)])
def map_grid():
    return build_mod.grid(_sources)


@app.get('/v1/activities', dependencies=[Depends(auth)])
def activities(b: Builder = Depends(builder)):
    return b.activities()


@app.get('/v1/planner/{sport}', dependencies=[Depends(auth)])
def planner(sport: str, day: int = 0, lat: float | None = None, lon: float | None = None, name: str | None = None,
            facing: float | None = None, b: Builder = Depends(builder)):
    """Planner for the built-in spot of a sport, or for the user's own place (lat/lon, name, beach facing)."""
    if sport not in SPORT_SPOT:
        raise HTTPException(404, 'unknown sport')
    if not 0 <= day <= 7:
        raise HTTPException(400, 'day must be 0–7')
    if lat is not None and lon is not None:
        _in_catalonia(lat, lon)
        b = Builder(_sources, b.p, custom=A.custom_spot(sport, lat, lon, name or f'{lat:.2f}, {lon:.2f}', facing))
    return b.planner(sport, day)


def _in_catalonia(lat: float, lon: float):
    if not (40.0 <= lat <= 43.5 and -0.5 <= lon <= 3.6):
        raise HTTPException(422, 'Oratge covers Catalonia only')


@app.get('/v1/shore', dependencies=[Depends(auth)])
def shore(lat: float, lon: float):
    """Which way a beach faces (degrees towards the sea), from terrain elevation around the point."""
    _in_catalonia(lat, lon)
    return A.shore_facing(_sources, lat, lon)


@app.post('/v1/activities/check', dependencies=[Depends(auth)])
async def activities_check(request: Request, b: Builder = Depends(builder)):
    """Best window per day for the user's spot activities: {"activities": [{id, sport, lat, lon, name, facing}], "days": 3}."""
    body = await _json(request, 64_000)
    items = [a for a in body.get('activities', []) if isinstance(a, dict)]
    days = max(1, min(7, int(body.get('days', 3))))
    return {'activities': A.check(lambda spot: Builder(_sources, b.p, custom=spot), items, days)}


@app.post('/v1/route', dependencies=[Depends(auth)])
async def route(request: Request, b: Builder = Depends(builder)):
    """Weather along a GPX track: {"points": [[lat, lon, ele?], …], "sport": "bike", "start": "2026-11-15T09:00", "speed": 24}."""
    body = await _json(request, 400_000)
    pts = body.get('points') or []
    sport = body.get('sport', 'bike')
    if sport not in ('bike', 'run', 'hike') or not isinstance(pts, list) or not 2 <= len(pts) <= 5000:
        raise HTTPException(422, 'expected points (2–5000) and sport bike, run or hike')
    try:
        start = datetime.fromisoformat(body.get('start') or datetime.now().strftime('%Y-%m-%dT%H:00'))
        points = [[float(p[0]), float(p[1]), (float(p[2]) if len(p) > 2 and p[2] is not None else None)] for p in pts]
    except (ValueError, TypeError, IndexError):
        raise HTTPException(422, 'bad start time or points')
    _in_catalonia(points[0][0], points[0][1])
    speed = body.get('speed')
    try:
        return A.route(_sources, b.p, points, sport, start.replace(tzinfo=None), float(speed) if speed else None)
    except ValueError as e:
        raise HTTPException(422, str(e))


async def _json(request: Request, limit: int) -> dict:
    raw = await request.body()
    if len(raw) > limit:
        raise HTTPException(413, 'payload too large')
    try:
        d = json.loads(raw)
        assert isinstance(d, dict)
        return d
    except Exception:
        raise HTTPException(422, 'expected a JSON object')


@app.get('/v1/map', dependencies=[Depends(auth)])
def map_(b: Builder = Depends(builder)):
    return b.map()


@app.get('/v1/spots', dependencies=[Depends(auth)])
def spots(b: Builder = Depends(builder)):
    return b.spots()


@app.get('/v1/spots/{sid}', dependencies=[Depends(auth)])
def spot(sid: str, b: Builder = Depends(builder)):
    if sid not in SPOTS:
        raise HTTPException(404, 'unknown spot')
    return b.spot(sid)


# ── Settings sync: profile, setup progress and favourite places, shared by the owner's devices ──
SYNC_MAX_KEYS, SYNC_MAX_BYTES = 400, 256_000


def sync_auth(authorization: str | None = Header(default=None)):
    """Unlike the read-only forecast routes, sync stores data: never without a configured token."""
    if not settings.app_token:
        raise HTTPException(403, 'sync needs ORATGE_TOKEN on the server')
    auth(authorization)


@app.get('/v1/sync', dependencies=[Depends(sync_auth)])
def sync_get():
    return {'fields': _store.sync_all(), 'now': time.time() * 1000}


@app.put('/v1/sync', dependencies=[Depends(sync_auth)])
async def sync_put(request: Request):
    raw = await request.body()
    if len(raw) > SYNC_MAX_BYTES:
        raise HTTPException(413, 'sync payload too large')
    try:
        fields = json.loads(raw)['fields']
        assert isinstance(fields, dict) and len(fields) <= SYNC_MAX_KEYS
        clean = {}
        for k, f in fields.items():
            assert isinstance(k, str) and 0 < len(k) <= 100 and isinstance(f, dict)
            clean[k] = {'v': f.get('v'), 't': float(f['t'])}
    except Exception:
        raise HTTPException(422, 'expected {"fields": {key: {"v": value, "t": epoch_ms}}}')
    stored = _store.sync_all()
    if len(stored.keys() | clean.keys()) > SYNC_MAX_KEYS:
        raise HTTPException(507, 'too many synced keys')
    changed = _store.sync_merge(clean)
    return {'fields': _store.sync_all(), 'changed': changed, 'now': time.time() * 1000}
