"""SQLite store: HTTP cache, Meteocat quota ledger, and the observation/forecast archive."""
import json
import sqlite3
import threading
import time
from datetime import datetime, timezone

# One connection shared by FastAPI's worker threads: every statement (reads too) must hold the lock,
# otherwise concurrent cursors on the same connection fail with 'bad parameter or other API misuse'.
_lock = threading.RLock()


class Store:
    def __init__(self, path: str):
        self.db = sqlite3.connect(path, check_same_thread=False)
        self.db.executescript('''
            create table if not exists cache (key text primary key, at real, body text);
            create table if not exists quota (month text, plan text, used integer, primary key (month, plan));
            create table if not exists archive (kind text, spot text, ts text, payload text, primary key (kind, spot, ts));
        ''')

    def _one(self, sql: str, args=()):
        with _lock:
            return self.db.execute(sql, args).fetchone()

    def _all(self, sql: str, args=()):
        with _lock:
            return self.db.execute(sql, args).fetchall()

    # ── cache ──
    def get(self, key: str, max_age: float):
        row = self._one('select at, body from cache where key=?', (key,))
        if row and time.time() - row[0] < max_age:
            return json.loads(row[1])
        return None

    def stale(self, key: str):
        row = self._one('select body from cache where key=?', (key,))
        return json.loads(row[0]) if row else None

    def put(self, key: str, body):
        with _lock:
            self.db.execute('insert or replace into cache values (?,?,?)', (key, time.time(), json.dumps(body)))
            self.db.commit()

    # ── quota governor ──
    @staticmethod
    def month() -> str:
        return datetime.now(timezone.utc).strftime('%Y-%m')

    def used(self, plan: str) -> int:
        row = self._one('select used from quota where month=? and plan=?', (self.month(), plan))
        return row[0] if row else 0

    def spend(self, plan: str):
        with _lock:
            self.db.execute('insert into quota values (?,?,1) on conflict(month, plan) do update set used=used+1',
                            (self.month(), plan))
            self.db.commit()

    # ── archive (forecast vs observation, history) ──
    def archive(self, kind: str, spot: str, ts: str, payload):
        with _lock:
            self.db.execute('insert or replace into archive values (?,?,?,?)', (kind, spot, ts, json.dumps(payload)))
            self.db.commit()

    def archived(self, kind: str, spot: str, since: str):
        rows = self._all('select ts, payload from archive where kind=? and spot=? and ts>=? order by ts',
                         (kind, spot, since))
        return [(ts, json.loads(p)) for ts, p in rows]
