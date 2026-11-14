"""Wing foil gear calculator: which wind your quiver works in, and which wing to take.

Rules of thumb (not measured; to be checked against the station archive once sessions exist):

- Minimum wind to get up and stay on foil with a 5 m² wing, rider 75 kg, mid board and foil:
  14 kn. +0.09 kn per kg above 75 (less below).
- Board: volume / weight ≥ 1.2 → −1.5 kn (floats, easy to pump); 1.0–1.2 → 0; 0.8–1.0 → +1.5;
  below 0.8 (sinker, needs a water start) → +3.
- Front wing: ≥ 1800 cm² −2.5; 1400–1800 −1.5; 1000–1400 0; 800–1000 +2; below 800 +4.
- Level: learning +2 (needs steady power to get up), riding upwind 0, jumping −1 (pumps up earlier).
- Other wing sizes: wing force ∝ area × wind², so the minimum scales with √(5 / area).
- Upper limit (gusts still controllable) for a 4 m² wing: 31 kn at 75 kg, +0.12 kn per kg;
  learning −7, jumping +3; scales with √(4 / area).

The app (lib/data/wing_calc.dart) uses the same numbers; tests in both check the same cases.
"""
from __future__ import annotations

import math

LEVELS_LOW = {'Learning': 2.0, 'Riding upwind': 0.0, 'Jumping': -1.0}
LEVELS_HIGH = {'Learning': -7.0, 'Riding upwind': 0.0, 'Jumping': 3.0}


def _num(x, default: float) -> float:
    try:
        return float(str(x).replace(',', '.').split()[0])
    except (TypeError, ValueError, IndexError):
        return default


def quiver(p: dict) -> list[float]:
    """Wing sizes the rider owns (m²), smallest first. Accepts ["4 m", "5 m"] or "4 m,5 m"."""
    raw = p.get('wings') or ['4 m', '5 m']
    if isinstance(raw, str):
        raw = raw.split(',')
    sizes = sorted({_num(w, 0) for w in raw if _num(w, 0) > 0})
    return sizes or [4.0, 5.0]


def gear(p: dict) -> dict:
    kg = _num(p.get('weight'), 78)
    vol = _num(p.get('boardVolume'), 95)
    fw = _num(p.get('frontWing'), 1100)
    level = p.get('wingLevel') if p.get('wingLevel') in LEVELS_LOW else 'Riding upwind'
    ratio = vol / kg if kg else 1
    board = -1.5 if ratio >= 1.2 else 0.0 if ratio >= 1.0 else 1.5 if ratio >= 0.8 else 3.0
    foil = -2.5 if fw >= 1800 else -1.5 if fw >= 1400 else 0.0 if fw >= 1000 else 2.0 if fw >= 800 else 4.0
    core = 14 + (kg - 75) * 0.09 + board + foil + LEVELS_LOW[level]  # minimum with a 5 m² wing
    top4 = 31 + (kg - 75) * 0.12 + LEVELS_HIGH[level]  # gust limit with a 4 m² wing
    wings = [{'size': a, 'low': round(core * math.sqrt(5 / a), 1), 'high': round(top4 * math.sqrt(4 / a), 1)}
             for a in quiver(p)]
    return {'wings': wings, 'min_wind': min(w['low'] for w in wings), 'max_gust': max(w['high'] for w in wings),
            'level': level, 'weight': kg, 'board': vol, 'front_wing': fw,
            'parts': {'base': round(14 + (kg - 75) * 0.09, 1), 'board': board, 'foil': foil, 'level': LEVELS_LOW[level]}}


def size_label(a: float) -> str:
    return f'{a:g} m'


def pick(g: dict, wind: float, gust: float) -> dict:
    """Biggest wing that gets you up in [wind] and stays controllable in [gust]."""
    fits = [w for w in g['wings'] if w['low'] <= wind and w['high'] >= gust]
    if fits:
        w = max(fits, key=lambda x: x['size'])
        margin = min(wind - w['low'], w['high'] - gust)
        return {'state': 'ok', 'size': w['size'],
                'text': f'{size_label(w["size"])}' + (' (at its limit)' if margin < 2 else '')}
    if wind < g['min_wind']:
        big = max(g['wings'], key=lambda x: x['size'])
        return {'state': 'under', 'size': big['size'],
                'text': f'Underpowered: your {size_label(big["size"])} needs about {big["low"]:.0f} kn'}
    small = min(g['wings'], key=lambda x: x['size'])
    if gust > small['high']:
        return {'state': 'over', 'size': small['size'],
                'text': f'Overpowered: gusts {gust:.0f} kn, your {size_label(small["size"])} holds about {small["high"]:.0f} kn'}
    # Between two wings: the bigger one is short of control, the smaller short of power.
    w = max((x for x in g['wings'] if x['high'] >= gust), key=lambda x: x['size'])
    return {'state': 'gap', 'size': w['size'], 'text': f'{size_label(w["size"])}, light for the lulls (gap in your quiver)'}


def score(g: dict, wind: float, gust: float) -> float:
    """1 when your quiver covers the hour, falling to 0 at 4 kn short or 6 kn over."""
    low = 1.0 if wind >= g['min_wind'] else max(0.0, 1 - (g['min_wind'] - wind) / 4)
    high = 1.0 if gust <= g['max_gust'] else max(0.0, 1 - (gust - g['max_gust']) / 6)
    return round(low * high, 2)
