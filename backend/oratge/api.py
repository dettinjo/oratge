"""Oratge backend API. All responses use the app's JSON contract (see app/lib/data/models.dart).

Planner/summary requests may carry the user's ranges as query parameters; they are used for the
rating and never stored.
"""
import logging

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware

import os

from .archive import start_scheduler
from .build import Builder
from .config import settings
from .sources import Sources
from .spots import SPORT_SPOT, SPOTS
from .store import Store

logging.basicConfig(level=logging.INFO)
app = FastAPI(title='Oratge', version='0.1.0')
# Read-only API protected by a bearer token; the web build may run on another origin.
app.add_middleware(CORSMiddleware, allow_origins=['*'], allow_methods=['GET'], allow_headers=['Authorization'])
_store = Store(settings.db_path)
_sources = Sources(_store)

PROFILE_KEYS = {'windFrom', 'windTo', 'gustLimit', 'waveFrom', 'waveTo', 'minPeriod', 'maxWindBike', 'comfortFrom',
                'comfortTo', 'maxStorm', 'maxSummitWind', 'weight', 'climbPace', 'daylightMargin', 'runDistance'}
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
    return Builder(_sources, p)


@app.on_event('startup')
def _archive():
    if os.environ.get('ORATGE_ARCHIVE', '1') == '1':
        start_scheduler(lambda: Builder(_sources))


@app.get('/health')
def health():
    return {'ok': True, 'meteocat': bool(settings.meteocat_key),
            'quota': {plan: {'used': _store.used(plan), 'limit': lim} for plan, lim in settings.quota.items()}}


@app.get('/v1/today', dependencies=[Depends(auth)])
def today(b: Builder = Depends(builder)):
    return b.today()


@app.get('/v1/activities', dependencies=[Depends(auth)])
def activities(b: Builder = Depends(builder)):
    return b.activities()


@app.get('/v1/planner/{sport}', dependencies=[Depends(auth)])
def planner(sport: str, day: int = 0, b: Builder = Depends(builder)):
    if sport not in SPORT_SPOT:
        raise HTTPException(404, 'unknown sport')
    if not 0 <= day <= 7:
        raise HTTPException(400, 'day must be 0–7')
    return b.planner(sport, day)


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
