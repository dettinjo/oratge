"""Endpoint + contract tests on recorded Open-Meteo responses (no network)."""
import json
import os
import pathlib

os.environ['ORATGE_DB'] = ':memory:'
os.environ.pop('METEOCAT_API_KEY', None)

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from oratge import api  # noqa: E402
from oratge.sources import Sources  # noqa: E402

FIX = pathlib.Path(__file__).parent / 'fixtures'
SAMPLE = pathlib.Path(__file__).resolve().parents[2] / 'app' / 'assets' / 'sample'


def fx(name):
    return json.loads((FIX / name).read_text())


class FakeSources(Sources):
    """Serves recorded responses for any coordinates."""

    def forecast(self, lat, lon, days=8):
        return fx('fc.json')

    def models(self, lat, lon, variable):
        return fx('mm.json')

    def marine(self, lat, lon):
        return fx('mar.json')

    def marine_models(self, lat, lon):
        return fx('marm.json')

    def ensemble(self, lat, lon, variable):
        d = fx('ens.json')
        if variable != 'wind_speed_10m':  # recorded fixture is wind; reuse its shape for other variables
            d['hourly'] = {('time' if k == 'time' else k.replace('wind_speed_10m', variable)): v for k, v in d['hourly'].items()}
        return d

    def _get(self, key, url, params, max_age, headers=None):
        # Archive requests: synthesise from the forecast's hourly wind.
        h = fx('fc.json')['hourly']
        return {'hourly': {'time': h['time'], 'wind_speed_10m': [w * 2.2 for w in h['wind_speed_10m']],
                           'wind_direction_10m': h['wind_direction_10m']}}


@pytest.fixture(autouse=True)
def fake(monkeypatch):
    monkeypatch.setattr(api, '_sources', FakeSources(api._store))
    # Pin "today" to the fixture's first full day so day slicing finds data.
    from oratge import build
    from datetime import date
    first = date.fromisoformat(fx('fc.json')['hourly']['time'][24][:10])
    monkeypatch.setattr(build, 'today_local', lambda: first)


client = TestClient(api.app)


def keys_match(live: dict, sample: dict, optional=()):
    missing = set(sample) - set(live) - set(optional)
    assert not missing, f'missing keys {missing}'


@pytest.mark.parametrize('path,sample', [
    ('/v1/today', 'today'), ('/v1/activities', 'activities'), ('/v1/map', 'map'),
    ('/v1/spots', 'spots'), ('/v1/spots/castelldefels', 'spot-castelldefels'),
    *[(f'/v1/planner/{s}', f'planner-{s}') for s in ('wing', 'surf', 'bike', 'run', 'hike')],
])
def test_endpoint_matches_contract(path, sample):
    r = client.get(path)
    assert r.status_code == 200, r.text
    live = r.json()
    ref = json.loads((SAMPLE / f'{sample}.json').read_text())
    keys_match(live, ref, optional=('chip',))
    if sample.startswith('planner'):
        assert live['hourChart']['rows'][0]['type'] == 'icons'
        assert len(live['days']) == 8
        assert 0 <= live['verdict']['rating'] <= 5
        keys_match(live['analysis'], ref['analysis'], optional=('station', 'ensemble'))


def test_profile_changes_rating():
    calm = client.get('/v1/planner/wing?windFrom=2&windTo=40').json()['verdict']['rating']
    strict = client.get('/v1/planner/wing?windFrom=35&windTo=40').json()['verdict']['rating']
    assert calm >= strict


def test_bad_inputs():
    assert client.get('/v1/planner/kite').status_code == 404
    assert client.get('/v1/planner/wing?day=9').status_code == 400
    assert client.get('/v1/planner/wing?windFrom=abc').status_code == 200


def test_token(monkeypatch):
    from oratge import config
    monkeypatch.setattr(api, 'settings', config.Settings(app_token='s3cret'))
    assert client.get('/v1/today').status_code == 401
    assert client.get('/v1/today', headers={'Authorization': 'Bearer s3cret'}).status_code == 200


def test_health_reports_quota():
    h = client.get('/health').json()
    assert h['ok'] and h['quota']['prediccio']['limit'] == 100
