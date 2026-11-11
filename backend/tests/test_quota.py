"""Quota governor: a day may only use its share of what is left, then serves the last known answer."""
import pytest

from oratge import sources as S
from oratge.store import Store


class Net(S.Sources):
    calls = 0

    def _get(self, key, url, params, max_age, headers=None):
        Net.calls += 1
        body = {'n': Net.calls}
        self.store.put(key, body)
        return body


@pytest.fixture
def src(monkeypatch, tmp_path):
    import dataclasses
    monkeypatch.setattr(S, 'settings', dataclasses.replace(S.settings, meteocat_key='k'))
    Net.calls = 0
    return Net(Store(str(tmp_path / 'q.db')))


def test_daily_share_is_enforced(monkeypatch, src):
    monkeypatch.setitem(S.settings.quota, 'xema', 750)
    first = src.allowance('xema')
    assert 1 <= first <= 750
    for i in range(first):
        src.meteocat('xema', f'/x/{i}', 0)
    assert src.allowance('xema') == 0
    # Over today's share: a path seen before comes from the stale cache, a new one is refused.
    assert src.meteocat('xema', '/x/0', 0) == {'n': 1}
    with pytest.raises(S.QuotaExceeded):
        src.meteocat('xema', '/x/new', 0)
    assert Net.calls == first


def test_sync_takes_the_higher_count(monkeypatch, src):
    monkeypatch.setattr(src, 'meteocat', lambda plan, path, max_age: {'plans': [
        {'nom': 'Predicció_100', 'maxConsultes': 100, 'consultesRealitzades': 7},
        {'nom': 'XEMA_750 OD', 'maxConsultes': 750, 'consultesRealitzades': 0}]})
    src.store.spend('xema')
    assert src.sync_quota()['prediccio'] == (7, 100)
    assert src.store.used('prediccio') == 7
    assert src.store.used('xema') == 1  # never lowers our own count


def test_query_string_reaches_meteocat(src, monkeypatch):
    seen = {}
    monkeypatch.setattr(src, '_get', lambda key, url, params, max_age, headers=None: seen.update(url=url, params=params) or [])
    src.meteocat('prediccio', '/pronostic/v2/smp/episodis-oberts?data=2026-11-11Z', 0)
    assert seen == {'url': 'https://api.meteo.cat/pronostic/v2/smp/episodis-oberts', 'params': {'data': '2026-11-11Z'}}
