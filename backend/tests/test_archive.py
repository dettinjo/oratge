from datetime import date, datetime, timedelta

from oratge import archive
from oratge.store import Store


def test_station_check_needs_seven_days_then_reports_bias():
    s = Store(':memory:')
    today = date(2026, 11, 20)
    for d in range(1, 6):
        day = today - timedelta(days=d)
        for hh in (12, 13, 14):
            ts = f'{day}T{hh:02d}:00'
            s.archive('fc', 'castelldefels', ts, {'wind': 15, 'gust': 20, 'temp': 18, 'wdir': 225, 'rating': 4})
            s.archive('obs', 'castelldefels', ts, {30: 17 / archive.MS_TO_KN})
    assert archive.station_check(s, 'wing', 'castelldefels', today) is None  # 5 days only
    for d in range(6, 10):
        day = today - timedelta(days=d)
        ts = f'{day}T13:00'
        s.archive('fc', 'castelldefels', ts, {'wind': 15, 'gust': 20, 'temp': 18, 'wdir': 225, 'rating': 4})
        s.archive('obs', 'castelldefels', ts, {30: 17 / archive.MS_TO_KN})
    chk = archive.station_check(s, 'wing', 'castelldefels', today, rate_obs=lambda ts, v: 4)
    assert chk and chk['tiles'][0]['value'] == '+2.0 kn'
    assert chk['tiles'][2]['value'] == '100 %'
    assert len(chk['trend']['values']) == len(chk['trend']['compare'])
