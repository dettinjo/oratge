"""Gear calculator: reference cases shared with app/test/wing_calc_test.dart (keep both in step)."""
from oratge import wingcalc as W

ME = {'weight': 78, 'boardVolume': 95, 'frontWing': 1100, 'wings': ['4 m', '5 m'], 'wingLevel': 'Riding upwind'}


def test_reference_rider():
    g = W.gear(ME)
    five = next(w for w in g['wings'] if w['size'] == 5)
    four = next(w for w in g['wings'] if w['size'] == 4)
    assert five['low'] == 12.8 and four['low'] == 14.3   # 14 + 0.27 − 1.5 (95 l / 78 kg ≥ 1.2)
    assert four['high'] == 31.4 and five['high'] == 28.0
    assert g['min_wind'] == 12.8 and g['max_gust'] == 31.4


def test_gear_moves_the_minimum():
    sinker = W.gear({**ME, 'boardVolume': 60})            # 0.77 l/kg → +3
    big_foil = W.gear({**ME, 'frontWing': 1900})          # −2.5
    learner = W.gear({**ME, 'wingLevel': 'Learning'})     # +2 low, −7 high
    assert sinker['min_wind'] > W.gear(ME)['min_wind'] + 4
    assert big_foil['min_wind'] < W.gear(ME)['min_wind'] - 2
    assert learner['min_wind'] > W.gear(ME)['min_wind'] and learner['max_gust'] < W.gear(ME)['max_gust']


def test_pick_wing():
    g = W.gear(ME)
    assert W.pick(g, 16, 20)['size'] == 5                 # both fit: take the bigger
    assert W.pick(g, 18, 30)['size'] == 4                 # gusts too strong for the 5
    assert W.pick(g, 10, 13)['state'] == 'under'
    assert W.pick(g, 28, 36)['state'] == 'over'
    assert W.quiver({'wings': '3 m, 4.5 m'}) == [3.0, 4.5]


def test_score_and_rating_cap():
    from datetime import datetime
    from oratge import engine as E
    g = W.gear(ME)
    assert W.score(g, 16, 20) == 1 and W.score(g, 8.8, 12) == 0 and W.score(g, 25, 37.4) == 0
    h = E.Hour(t=datetime(2026, 11, 14, 13), temp=18, feels=18, rh=60, precip=0, pprob=0, code=1, wind=9, wdir=170,
               gust=11, uv=2, cape=0, freezing=3000, pressure=1015, cloud=10, daylight=True, wave=0.3)
    r = E.rate('wing', h, {'shore_facing': 170}, {**E.DEFAULT_PROFILE, **ME, 'windFrom': 8, 'windTo': 24})
    assert r.rating <= 2   # in the rider's own range, but the gear can't get them foiling
