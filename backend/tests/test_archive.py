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


def test_store_is_thread_safe(tmp_path):
    """Concurrent reads and writes on the shared connection (FastAPI thread pool) must not error."""
    from concurrent.futures import ThreadPoolExecutor
    from oratge.store import Store
    st = Store(str(tmp_path / 'c.db'))

    def work(i):
        for j in range(200):
            st.put(f'k{i}:{j % 5}', {'v': j})
            st.get(f'k{(i + 1) % 8}:{j % 5}', 60)
            st.stale(f'k{i}:{j % 5}')
            st.used('pred')
        return True

    with ThreadPoolExecutor(8) as ex:
        assert all(ex.map(work, range(8)))
