from datetime import datetime

from oratge import engine as E


def hour(**kw):
    base = dict(t=datetime(2026, 11, 10, 14), temp=18, feels=17, rh=60, precip=0, pprob=0, code=1, wind=17, wdir=225,
                gust=21, uv=2, cape=0, freezing=2800, pressure=1015, cloud=20, daylight=True, wave=0.5)
    base.update(kw)
    return E.Hour(**base)


SPOT = {'shore_facing': 170, 'exposure': [40, 180]}
P = dict(E.DEFAULT_PROFILE)


def test_shore_relation():
    assert E.shore_relation(170, 170) == 'on'
    assert E.shore_relation(225, 170) == 'side-on'
    assert E.shore_relation(260, 170) == 'side'
    assert E.shore_relation(350, 170) == 'off'


def test_wing_good_and_offshore_stop():
    assert E.rate('wing', hour(), SPOT, P).rating >= 4
    assert E.rate('wing', hour(wdir=350), SPOT, P).rating == 0
    assert E.rate('wing', hour(daylight=False), SPOT, P).rating == 0


def test_surf_flat_is_capped():
    r = E.rate('surf', hour(swell=0.3, swell_period=4, swell_dir=100, wdir=300, wind=3), SPOT, P)
    assert r.rating <= 1


def test_hike_storm_lowers_rating():
    calm = E.rate('hike', hour(cape=0), SPOT, P).rating
    stormy = E.rate('hike', hour(cape=900, pprob=80, code=95), SPOT, P).rating
    assert stormy < calm


def test_best_window_is_compact():
    rated = [E.Rated(hour(t=datetime(2026, 11, 10, h)), 4, total=4.2) for h in range(7, 21)]
    w = E.best_window(rated)
    assert w and w[1] - w[0] <= 5
    w3 = E.best_window(rated, length=3)
    assert w3[1] - w3[0] == 3
