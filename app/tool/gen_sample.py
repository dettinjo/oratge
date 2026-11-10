#!/usr/bin/env python3
"""Generate the app's sample data (assets/sample/*.json) from the Claude Design handoff.

The JSON shapes written here are the app <-> backend contract (see lib/data/models.dart).
Run from the app directory:  python3 tool/gen_sample.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
HANDOFF = ROOT.parent / 'design' / 'handoff' / 'design'
OUT = ROOT / 'assets' / 'sample'
OUTLINE = HANDOFF / 'screens' / 'outline'
LOGIC = json.loads((HANDOFF / 'logic' / 'planner-logic.json').read_text(encoding='utf-8'))

WEATHER_MODELS = [('Meteocat', 'municipal + beach forecast'), ('AROME', '1.3 km · Météo-France'),
                  ('ARPEGE', '10 km · Météo-France'), ('ICON-EU', '7 km · DWD'), ('ECMWF IFS', '9 km'),
                  ('GFS', '13 km · NOAA')]
WAVE_MODELS = [('Meteocat', 'beach forecast'), ('MFWAM', 'Météo-France waves'), ('DWD EWAM', '5 km · DWD'),
               ('ECMWF WAM', '9 km'), ('GFS WaveWatch III', '25 km · NOAA')]


def load(name):
    return json.loads((OUTLINE / f'{name}.json').read_text(encoding='utf-8'))['outline'][0]


def texts(n):
    """All string children (recursively)."""
    out = []
    if isinstance(n, str):
        return [n]
    for c in n.get('children') or []:
        out += texts(c)
    return out


def comps(n, name=None):
    out = []
    if isinstance(n, dict):
        if 'component' in n and (name is None or n['component'] == name):
            out.append(n)
        for c in n.get('children') or []:
            out += comps(c, name)
    return out


def label_of(section):
    for c in section.get('children') or []:
        if isinstance(c, dict) and c.get('component') == 'SectionLabel':
            return ' '.join(texts(c))
    return None


def sections(root):
    return [c for c in root['children'] if isinstance(c, dict) and c.get('el') == 'section']


def header(root):
    h = [c for c in root['children'] if isinstance(c, dict) and c.get('el') == 'header'][0]
    h1 = [c['text'] for c in h['children'] if isinstance(c, dict) and c.get('el') == 'h1'][0]
    p = [c['text'] for c in h['children'] if isinstance(c, dict) and c.get('el') == 'p'][0]
    return h1, p


def fact(n):
    p = dict(n['props'])
    return {k: p[k] for k in ('label', 'value', 'sub', 'accent', 'size') if p.get(k) is not None}


def block(n):
    return {'type': n['component'], 'props': n.get('props') or {}}


def sources(root):
    ds = comps(root, 'DataSources')
    return ' '.join(texts(ds[0])) if ds else ''


def planner(sport, name):
    root = load(name)
    title, date = header(root)
    logic = LOGIC[sport]
    res = {'sport': sport, 'title': title, 'date': date, 'keyFacts': [], 'tuned': [], 'visuals': [],
           'plan': None, 'outlook': None, 'chip': None}
    fact_sections = []
    for s in sections(root):
        lab = label_of(s)
        dt = comps(s, 'DayTabs')
        if dt and lab is None:
            res['days'] = dt[0]['props']['days']
            res['selected'] = dt[0]['props'].get('selected', 0)
            continue
        vc = comps(s, 'VerdictCard')
        if vc:
            res['verdict'] = vc[0]['props']
            continue
        if any(isinstance(c, dict) and c.get('el') == 'details' for c in s['children']):
            res['analysis'] = analysis(sport, s, logic)
            continue
        if comps(s, 'DataSources'):
            continue
        if lab == 'Hour by hour':
            hc = comps(s, 'HourChart')[0]['props']
            res['takeaway'] = [c['text'] for c in s['children'] if isinstance(c, dict) and c.get('el') == 'p'][0]
            if sport == 'surf':
                for r in hc['rows']:
                    if r.get('type') == 'arrows' and r.get('shore'):
                        r['offshoreGood'] = True
            res['hourChart'] = hc
            continue
        if lab == 'Tuned to you':
            res['tuned'] = [{'from': t['fromProfile'], 'effect': t['effect']} for t in logic['tunedToYou']]
            continue
        facts = comps(s, 'FactTile')
        others = [c for c in comps(s) if c['component'] not in ('SectionLabel', 'FactTile', 'Card', 'ChipGroup')]
        chip = comps(s, 'ChipGroup')
        if chip and not facts and not others:
            res['chip'] = chip[0]['props']
            continue
        if facts and not others:
            fact_sections.append((lab, [fact(f) for f in facts]))
            chip = comps(s, 'ChipGroup')
            if chip:
                res['chip'] = chip[0]['props']
            continue
        if lab and lab.startswith('Next 3 days'):
            res['outlook'] = {'label': lab, 'block': block(others[0])}
            continue
        if others:
            res['visuals'].append({'label': lab, 'blocks': [block(o) for o in others]})
    res['keyLabel'], res['keyFacts'] = fact_sections[0]
    if len(fact_sections) > 1:
        res['plan'] = {'label': fact_sections[1][0], 'facts': fact_sections[1][1]}
    res['sources'] = sources(root)
    return res


def analysis(sport, s, logic):
    det = [c for c in s['children'] if isinstance(c, dict) and c.get('el') == 'details'][0]
    kids = det['children']
    labels = [i for i, c in enumerate(kids) if isinstance(c, dict) and c.get('component') == 'SectionLabel']
    blocks = {' '.join(texts(kids[i])): kids[i + 1] for i in labels}
    ma = logic['modelAgreement']
    models = WAVE_MODELS if sport == 'surf' else WEATHER_MODELS
    model_card = blocks[ma['title']]
    scale_txt = next(t for t in texts(model_card) if t.startswith('model blend scale'))
    nums = [float(x) for x in re.findall(r'[-\d.]+', scale_txt.replace('–', ' '))]
    ens_label = next(k for k in blocks if k.startswith('Ensemble'))
    ens = blocks[ens_label]
    st_label = next(k for k in blocks if k.startswith('Station check') or k.startswith('Buoy check'))
    st = blocks[st_label]
    st_texts = texts(st)
    return {
        'summary': logic['analysisSummary'],
        'model': {'title': ma['title'], 'unit': ma['unit'], 'scale': nums[:2], 'blend': ma['blend'],
                  'spread': ma['spread'], 'verdict': ma['verdict'],
                  'rows': [{'name': m[0], 'detail': m[1], 'value': v, 'weight': w}
                           for m, v, w in zip(models, ma['vals'], ma['weights'])]},
        'factors': [{'factor': f['factor'], 'observed': f['observed'], 'weight': f['weightPct'],
                     'score': f['score'], 'accent': f['accent']} for f in logic['ratingFactors']],
        'total': logic['ratingTotal'], 'rating': logic['rating'],
        'ensemble': {'label': ens_label, 'intro': texts(ens)[0], 'chart': comps(ens, 'HourChart')[0]['props']},
        'station': {'title': st_label, 'trend': comps(st, 'TrendLine')[0]['props'],
                    'legend': st_texts[0], 'note': st_texts[1],
                    'tiles': [fact(f) for f in comps(st, 'FactTile')]},
    }


def today():
    root = load('phone-today')
    title, date = header(root)
    secs = sections(root)
    best_card = comps(secs[0], 'Card')[0]
    bt = texts(best_card)
    sport_word, window = bt[1].split(' · ', 1)
    sport = {'Bike': 'bike', 'Wing': 'wing', 'Surf': 'surf', 'Run': 'run', 'Hike': 'hike'}[sport_word]
    out = {'title': title, 'date': date,
           'best': {'sport': sport, 'window': window, 'rating': comps(best_card, 'RatingDots')[0]['props']['value'],
                    'reason': bt[2], 'note': bt[3] if len(bt) > 3 else None},
           'warnings': [dict(w['props'], pre=w['props'].get('kind') == 'pre') for w in comps(root, 'WarningBanner')],
           'current': comps(root, 'CurrentConditions')[0]['props'],
           'sources': sources(root)}
    for s in secs:
        lab = label_of(s)
        if lab == 'Right now':
            out['rightNow'] = [fact(f) for f in comps(s, 'FactTile')]
        elif lab == 'Next 24 hours':
            p = comps(s, 'NextHours')[0]['props']
            out['next24'] = {k: p[k] for k in ('startHour', 'temps', 'rain', 'sky')}
        elif lab == 'Today for you':
            out['sports'] = [a['props'] for a in comps(s, 'ActivityRow')]
        elif lab == '7 days':
            rows = comps(s, 'ForecastDayRow')
            out['days'] = [{k: r['props'][k] for k in ('day', 'sky', 'rainChance', 'min', 'max')} for r in rows]
            out['scale'] = rows[0]['props']['scale']
        elif lab == 'Forecast confidence':
            t = texts(s)[1:]
            rows = []
            for line in t[1:]:
                m = re.match(r'^(\S+)\s+(.*)\s+(\d+)\s*%$', line)
                if m:
                    rows.append({'day': m.group(1), 'label': m.group(2), 'pct': int(m.group(3))})
            out['confidence'] = {'intro': t[0], 'rows': rows}
        elif lab == 'Daylight':
            out['daylight'] = [fact(f) for f in comps(s, 'FactTile')]
    return out


def activities():
    root = load('phone-activities')
    title, date = header(root)
    return {'title': title, 'date': date,
            'sports': [a['props'] for a in comps(root, 'ActivityRow')],
            'chip': comps(root, 'ChipGroup')[0]['props'],
            'days': comps(root, 'DayTabs')[0]['props']['days'],
            'heatmap': comps(root, 'CalendarHeatmap')[0]['props'],
            'months': comps(root, 'MonthBars')[0]['props'],
            'sources': sources(root)}


def map_screen():
    root = load('phone-map')
    title, date = header(root)
    spots = comps(load('phone-spots'), 'SpotCard')
    # Pin positions on a schematic Catalonia map (0–1 coordinates), placeholder until a real base map.
    pins = {'Castelldefels': (0.56, 0.74), 'Ocata': (0.70, 0.62), 'Collserola loop': (0.62, 0.66),
            "Montseny · Turó de l'Home": (0.68, 0.48), 'Pedraforca': (0.48, 0.24)}
    coords = {'Castelldefels': (41.265, 1.975), 'Ocata': (41.477, 2.338), 'Collserola loop': (41.418, 2.118),
              "Montseny · Turó de l'Home": (41.778, 2.436), 'Pedraforca': (42.239, 1.703)}
    ids = {'Castelldefels': ('castelldefels', 'wing'), 'Ocata': ('ocata', 'surf'), 'Collserola loop': ('collserola', 'bike'),
           "Montseny · Turó de l'Home": ('montseny', 'hike')}
    pin_list = [{'id': ids[s['props']['name']][0], 'sport': ids[s['props']['name']][1], 'window': s['props']['window'],
                 'gust': s['props']['gust'],
                 'name': s['props']['name'], 'rating': s['props']['rating'], 'x': pins[s['props']['name']][0],
                 'y': pins[s['props']['name']][1], 'wind': s['props']['wind'], 'windFrom': s['props']['windFrom'],
                 'lat': coords[s['props']['name']][0], 'lon': coords[s['props']['name']][1]}
                for s in spots]
    pin_list.append({'id': 'pedraforca', 'sport': 'hike', 'window': '07–12 h', 'gust': 34, 'name': 'Pedraforca', 'rating': 2, 'x': 0.48, 'y': 0.24, 'wind': 22, 'windFrom': 310,
                     'lat': 42.239, 'lon': 1.703})
    return {'title': title, 'date': date, 'layers': comps(root, 'ChipGroup')[0]['props'],
            'pins': pin_list,
            'warnings': [w['props'] for w in comps(root, 'WarningBanner')],
            'sources': sources(root)}


def spots():
    root = load('phone-spots')
    title, date = header(root)
    ids = ['castelldefels', 'ocata', 'collserola', 'montseny']
    sports = ['wing', 'surf', 'bike', 'hike']
    return {'title': title, 'date': date,
            'spots': [dict(s['props'], id=i, sport=sp) for s, i, sp in zip(comps(root, 'SpotCard'), ids, sports)]}


def spot():
    root = load('phone-spot')
    title, date = header(root)
    out = {'id': 'castelldefels', 'title': title, 'date': date, 'sources': sources(root), 'sections': []}
    for s in sections(root):
        lab = label_of(s)
        facts = comps(s, 'FactTile')
        others = [c for c in comps(s) if c['component'] not in ('SectionLabel', 'FactTile', 'Card', 'DataSources')]
        if facts and not others:
            out['live'] = [fact(f) for f in facts]
        elif others:
            out['sections'].append({'label': lab, 'blocks': [block(o) for o in others]})
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    files = {'today': today(), 'activities': activities(), 'map': map_screen(), 'spots': spots(),
             'spot-castelldefels': spot()}
    for sport in ('wing', 'surf', 'bike', 'run', 'hike'):
        files[f'planner-{sport}'] = planner(sport, f'phone-{sport}')
    for k, v in files.items():
        (OUT / f'{k}.json').write_text(json.dumps(v, ensure_ascii=False, indent=1), encoding='utf-8')
        print(f'{k}.json', len(json.dumps(v)))


if __name__ == '__main__':
    main()
