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

    def places(self, q):
        return {'results': [{'name': 'Sitges', 'admin1': 'Catalonia', 'admin2': 'Barcelona', 'latitude': 41.235, 'longitude': 1.812},
                            {'name': 'Sitges', 'admin1': 'Andalusia', 'latitude': 37.0, 'longitude': -4.0}]}

    def reverse(self, lat, lon):
        if lat < 41.23:  # offshore: Nominatim only knows the country
            return {'name': 'España', 'addresstype': 'country', 'address': {'country': 'España'}}
        return {'name': 'Sitges', 'address': {'town': 'Sitges'}}

    def reverse_nearest(self, lat, lon):
        return {'features': [{'properties': {'name': 'JetCenter', 'city': 'Sitges'}}]}

    def grid(self, lats, lons):
        return [{'latitude': a, 'longitude': b, 'current': {'time': '2026-11-10T09:00', 'wind_speed_10m': 10, 'wind_direction_10m': 220,
                 'wind_gusts_10m': 15, 'temperature_2m': 17, 'precipitation': 0}} for a, b in zip(lats, lons)]

    def grid_forecast(self, lats, lons, hours=48):
        times = [f'2026-11-10T{h:02d}:00' for h in range(hours)][:hours]
        hourly = {'time': times, 'wind_speed_10m': [10.0] * hours, 'wind_direction_10m': [220] * hours, 'wind_gusts_10m': [15.0] * hours,
                  'temperature_2m': [17.0] * hours, 'precipitation': [0.0] * hours, 'precipitation_probability': [10] * hours,
                  'weather_code': [3] * hours}
        return [{'latitude': a, 'longitude': b, 'hourly': hourly} for a, b in zip(lats, lons)]

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


def test_today_for_a_place():
    d = client.get('/v1/today?lat=41.235&lon=1.812&place=Sitges').json()
    assert d['current']['place'] == 'Sitges' and d['place']['lat'] == 41.235
    assert {'wind', 'gust', 'uv'} <= set(d['next24'])
    assert client.get('/v1/today?lat=48.8&lon=2.3').status_code == 400  # Paris is outside Catalonia


def test_places_only_catalonia():
    assert client.get('/v1/places?q=Sitges').json()['places'] == [{'name': 'Sitges', 'region': 'Barcelona', 'lat': 41.235, 'lon': 1.812}]


def test_reverse_and_grid():
    assert client.get('/v1/reverse?lat=41.24&lon=1.81').json()['name'] == 'Sitges'
    assert client.get('/v1/reverse?lat=41.225&lon=1.821').json()['name'] == 'Sitges'  # offshore → nearest town
    g = client.get('/v1/map/grid').json()
    assert len(g['points']) > 50 and g['time'] == '09:00'


def test_map_forecast_grid():
    d = client.get('/v1/map/forecast?hours=12').json()
    n = len(d['lats']) * len(d['lons'])
    assert len(d['times']) == 12 and len(d['fields']['wind']) == 12 and len(d['fields']['wind'][0]) == n
    assert set(d['fields']) == {'wind', 'wdir', 'gust', 'temp', 'precip', 'pprob', 'code'}


class KeyedSources(FakeSources):
    """As if a Meteocat key were set: XEMA calls answer with recorded readings (Viladecans has no anemometer)."""

    def meteocat_available(self):
        return True

    def try_meteocat(self, plan, path, max_age):
        if path.startswith('/xema/v1/estacions/metadades'):
            return [{**s, 'comarca': s['comarca']} for s in fx('xema_stations.json')]
        if path.startswith('/xema/v1/variables/mesurades/30/ultimes'):
            return fx('xema_ult30.json')
        if path.startswith('/xema/v1/estacions/mesurades/'):
            code = path.split('/')[5]
            return fx('xema.json').get({'XL': 'YV', 'Z9': 'YV', 'UI': 'YY', 'X4': 'YV', 'XV': 'YV'}.get(code, code))
        if path.startswith('/xdde/'):
            return []
        if path.startswith('/pronostic/v1/platges/'):
            return fx('mc_beach.json')
        if path.startswith('/pronostic/v1/pirineu/pics/'):
            return fx('mc_summit.json')
        return None

    def allowance(self, plan):
        return 5


def test_live_takes_wind_from_the_wind_station():
    from oratge.build import Builder
    from oratge.spots import SPOTS
    b = Builder(KeyedSources(api._store), {})
    xema = fx('xema.json')
    last = lambda st, c: next(v for v in xema[st][0]['variables'] if v['codi'] == c)['lectures'][-1]['valor']  # noqa: E731
    live = b.live(SPOTS['castelldefels'])
    assert live['temp'] == last('YY', 32)  # own station
    assert live['wind'] == pytest.approx(last('YV', 30) * 1.94384, abs=0.05)  # wind station
    assert live['wdir'] == last('YV', 31)


def test_station_without_wind_is_not_zero_knots():
    from oratge.build import Builder
    from oratge.meteocat import Meteocat

    class NoWindNearby(KeyedSources):
        def try_meteocat(self, plan, path, max_age):
            return [] if 'ultimes' in path else super().try_meteocat(plan, path, max_age)

    live = Meteocat(NoWindNearby(api._store)).live(41.27, 2.0, station='YY')
    assert live['temp'] is not None and live['wind'] is None and live['gust'] is None


def test_spot_page_with_meteocat_key(monkeypatch):
    monkeypatch.setattr(api, '_sources', KeyedSources(api._store))
    for sid in ('castelldefels', 'pedraforca', 'ocata'):
        r = client.get(f'/v1/spots/{sid}')
        assert r.status_code == 200, r.text
        assert 'XEMA station' in r.json()['sources']


def test_warnings_from_real_episode():
    """Recorded episodis-oberts (11 Nov 2026 wind episode): only our comarques, local times, English thresholds."""
    from oratge.build import Builder

    class S(KeyedSources):
        def try_meteocat(self, plan, path, max_age):
            return fx('avisos.json') if 'episodis' in path else super().try_meteocat(plan, path, max_age)

    ws = Builder(S(api._store)).warnings()
    assert ws and len(ws) <= 4
    assert all(w['level'] in ('yellow', 'orange', 'red') for w in ws)
    assert len(ws) == 1  # same hazard, level and threshold in four comarques → one card
    w = ws[0]
    assert w['title'] == 'Yellow warning · Wind'
    assert w['detail'] == 'Castelldefels, Collserola loop, Passeig Marítim, Barcelona, Ocata · Thu 07–19 h · gusts above 72 km/h'
    assert w['areas'] == ['Baix Llobregat', 'Barcelonès', 'Maresme', 'Vallès Occidental']


@pytest.mark.parametrize('name,thr,title,text', [
    ('Vent', 'Ratxa màxima > 90 km/h (25 m/s)', 'Wind', 'gusts above 90 km/h'),
    ('Intensitat de pluja en 30 minuts', 'Intensitat > 20 mm / 30 minuts', 'Heavy rain', 'over 20 mm in 30 min'),
    ('Acumulació de pluja', 'Acumulada > 100 mm /24 hores', 'Rain (24 h total)', 'over 100 mm in 24 h'),
])
def test_warning_texts_in_english(name, thr, title, text):
    from oratge.build import meteor_en, threshold_en
    assert meteor_en(name) == title and threshold_en(thr) == text


@pytest.fixture
def synced(monkeypatch):
    """Sync needs a server token; requests below carry it."""
    import dataclasses
    monkeypatch.setattr(api, 'settings', dataclasses.replace(api.settings, app_token='t'))
    client.headers['Authorization'] = 'Bearer t'
    yield
    client.headers.pop('Authorization', None)


def test_sync_refused_without_server_token():
    assert client.get('/v1/sync').status_code == 403


def test_sync_last_writer_wins_per_key(synced):
    from oratge.store import Store
    st = Store(':memory:')
    api_store = api._store
    api._store = st
    try:
        r = client.put('/v1/sync', json={'fields': {'p.windFrom': {'v': '12', 't': 1000}, 'p.name': {'v': 'Joel', 't': 1000}}})
        assert r.status_code == 200 and r.json()['changed'] == 2
        # Another device: newer wind range, older name → only the wind range changes.
        r = client.put('/v1/sync', json={'fields': {'p.windFrom': {'v': '15', 't': 2000}, 'p.name': {'v': 'Alex', 't': 500}}})
        assert r.json()['changed'] == 1
        f = client.get('/v1/sync').json()['fields']
        assert f['p.windFrom'] == {'v': '15', 't': 2000} and f['p.name']['v'] == 'Joel'
        # Lists and deletions (null) round-trip.
        client.put('/v1/sync', json={'fields': {'favorites': {'v': [{'name': 'Sitges', 'lat': 41.2, 'lon': 1.8}], 't': 3000},
                                                'p.ftp': {'v': None, 't': 3000}}})
        f = client.get('/v1/sync').json()['fields']
        assert f['favorites']['v'][0]['name'] == 'Sitges' and f['p.ftp']['v'] is None
    finally:
        api._store = api_store


def test_sync_rejects_bad_payloads(synced):
    client.headers['Authorization'] = 'Bearer wrong'
    assert client.get('/v1/sync').status_code == 401
    client.headers['Authorization'] = 'Bearer t'
    assert client.put('/v1/sync', json={'nope': 1}).status_code == 422
    assert client.put('/v1/sync', json={'fields': {'k': {'v': 1}}}).status_code == 422  # no timestamp
    assert client.put('/v1/sync', content=b'x' * 300_000).status_code == 413


def test_meteocat_products_parse_real_responses():
    from oratge.meteocat import Meteocat
    mc = Meteocat(KeyedSources(api._store))
    # Nearest station and comarca for an arbitrary point (Sitges → Garraf area).
    st = mc.nearest(41.237, 1.81)
    assert st and st['km'] < 15
    assert mc.nearest(41.237, 1.81, wind=True)['code'] in {s['codi'] for s in fx('xema_ult30.json')}
    # Beach: hourly, wind converted to kn, waves and water temperature present.
    b = mc.beach('castelldefels-de-castelldefels-2-lluminetes')
    assert len(b) >= 20 and b[0]['wave'] == 0.8 and b[0]['sst'] == 20.6 and b[0]['wind'] == pytest.approx(1.7 * 1.94384, abs=0.05)
    # Summit: 3-hourly bands with freezing level.
    s = mc.summit('el-pedraforca')
    assert len(s) == 8 and s[0]['freezing'] == 3200 and 2500 in s[0]['levels'] and s[0]['levels'][2500]['wind'] > 0
    # Lightning: an empty hour is "no strikes", not missing data.
    assert mc.lightning(41.4, 2.1) == {'count': 0, 'near': 0, 'nearest_km': None, 'last': None, 'radius': 30}


def test_lightning_counts_strikes_near_the_point():
    from oratge.meteocat import Meteocat

    class Storm(KeyedSources):
        def try_meteocat(self, plan, path, max_age):
            if path.startswith('/xdde/'):
                return [{'data': '2026-11-12T03:10Z', 'coordenades': {'latitud': 41.40, 'longitud': 2.15}},
                        {'data': '2026-11-12T03:20Z', 'coordenades': {'latitud': 41.60, 'longitud': 2.15}},
                        {'data': '2026-11-12T03:30Z', 'coordenades': {'latitud': 42.50, 'longitud': 2.15}}]
            return super().try_meteocat(plan, path, max_age)

    lt = Meteocat(Storm(api._store)).lightning(41.39, 2.16)
    assert lt['count'] == 4 and lt['near'] == 2 and lt['nearest_km'] < 2  # two hours × two strikes within 30 km


def test_planners_include_meteocat_sections(monkeypatch):
    monkeypatch.setattr(api, '_sources', KeyedSources(api._store))
    wing = client.get('/v1/planner/wing').json()
    labels = [v['label'] for v in wing['visuals']]
    assert 'Meteocat beach forecast' in labels
    hike = client.get('/v1/planner/hike').json()
    assert any(v['label'].startswith('Meteocat summit forecast') for v in hike['visuals'])
    today = client.get('/v1/today').json()
    assert today['observed']['station'] and today['observed']['lightning']['count'] == 0


def test_hourly_detail_series(monkeypatch):
    monkeypatch.setattr(api, '_sources', KeyedSources(api._store))
    d = client.get('/v1/hourly?lat=41.39&lon=2.16&place=Barcelona').json()
    n = len(d['times'])
    assert n >= 24 and all(len(v) == n for v in d['series'].values())
    assert d['days'][0]['day'] == 'Today' and d['days'][0]['sunrise']
    assert d['observed']['station'] and 'temp' in d['observed']['series']
    assert client.get('/v1/hourly?lat=48.8&lon=2.3').status_code == 422


def test_alerts_have_stable_ids():
    a = client.get('/v1/alerts?sports=wing,bike').json()
    b = client.get('/v1/alerts?sports=wing,bike').json()
    assert [x['id'] for x in a['alerts']] == [x['id'] for x in b['alerts']]
    assert all(x['kind'] in ('window', 'warning') and x['title'] and x['route'] for x in a['alerts'])
    assert {r['sport'] for r in a['ratings'].values()} <= {'wing', 'bike'}


def test_old_apps_only_get_default_alerts():
    old = client.get('/v1/alerts?sports=wing,bike,run').json()
    assert all((a['kind'] == 'window' and a['sport'] == 'wing') or a.get('level') in ('orange', 'red') for a in old['alerts'])
    assert {r['sport'] for r in old['ratings'].values()} <= {'wing'}
    new = client.get('/v1/alerts?sports=wing,bike,run&v=2').json()
    assert all('rating' in a and 'days_ahead' in a for a in new['alerts'] if a['kind'] == 'window')
