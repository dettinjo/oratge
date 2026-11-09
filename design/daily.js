/* Oratge mockups v2 — daily planners (one per sport).
   Relies on globals from the main script: C, R, el, icon, dots, LINE, T2, T3. */

const HOURS = [7,8,9,10,11,12,13,14,15,16,17,18,19,20];
const W = 326, LAB = 54, CW = (W - LAB) / HOURS.length;
const cx = i => LAB + i * CW + CW / 2;
const TXT = '#F1EBE2';

/* ---------- meteogram: one SVG, one row per variable, shared hour columns ---------- */
function meteogram(host, rows, o = {}) {
  const rise = o.sunrise ?? 7.6, set = o.sunset ?? 17.58;
  const heights = rows.map(r => r.h);
  const total = 18 + heights.reduce((a, b) => a + b, 0);
  const s = el(host, 'svg', { width: W, height: total });
  const hx = h => LAB + (h - HOURS[0]) * CW;
  // night shading across all rows
  el(s, 'rect', { x: LAB, y: 14, width: hx(rise) - LAB, height: total - 14, fill: '#1A1814' });
  el(s, 'rect', { x: hx(set), y: 14, width: W - hx(set), height: total - 14, fill: '#1A1814' });
  // hour axis
  HOURS.forEach((h, i) => { if (h % 2 === 0) el(s, 'text', { x: cx(i), y: 10, 'font-size': 9.5, fill: T3, 'text-anchor': 'middle' }, String(h).padStart(2, '0')); });
  if (o.best) el(s, 'rect', { x: hx(o.best[0]), y: 13, width: hx(o.best[1]) - hx(o.best[0]), height: total - 13, rx: 6, fill: 'none', stroke: TXT, 'stroke-opacity': .55, 'stroke-dasharray': '2 3' });
  let y = 18;
  rows.forEach((r, k) => {
    if (k) el(s, 'line', { x1: 0, x2: W, y1: y, y2: y, stroke: LINE, 'stroke-width': .6 });
    const ly = y + Math.min(r.h / 2 + 4, 15);
    const t = el(s, 'text', { x: 0, y: ly, 'font-size': 10, fill: T2, 'font-weight': 500 }, r.label);
    if (r.unit && r.h >= 32) el(s, 'text', { x: 0, y: ly + 11, 'font-size': 8.5, fill: T3 }, r.unit);
    else if (r.unit) el(t, 'tspan', { 'font-size': 8.5, fill: T3, 'font-weight': 400, dx: 3 }, r.unit);
    ROW[r.type](s, y, r);
    y += r.h;
  });
  return s;
}
const ROW = {
  icons(s, y, r) { r.v.forEach((k, i) => { if (i % 2 === 0 || r.all) { const g = el(s, 'g', { transform: `translate(${cx(i) - 9} ${y + 3}) scale(.75)` }); g.innerHTML = icon(k, 24).replace(/^<svg[^>]*>|<\/svg>$/g, ''); } }); },
  rating(s, y, r) { r.v.forEach((v, i) => el(s, 'rect', { x: LAB + i * CW + 1, y: y + 4, width: CW - 2, height: r.h - 8, rx: 3, fill: v ? R[v - 1] : '#24201B' })); },
  line(s, y, r) {
    const pad = 10, top = y + pad, bot = y + r.h - 6, lo = r.min, hi = r.max;
    const yy = v => bot - (v - lo) / (hi - lo) * (bot - top);
    if (r.range) {
      const id = 'h' + Math.random().toString(36).slice(2, 7);
      const p = el(el(s, 'defs'), 'pattern', { id, width: 5, height: 5, patternUnits: 'userSpaceOnUse', patternTransform: 'rotate(45)' });
      el(p, 'rect', { width: 2, height: 5, fill: '#3A342C' });
      el(s, 'rect', { x: LAB, y: yy(Math.min(r.range[1], hi)), width: W - LAB, height: yy(r.range[0]) - yy(Math.min(r.range[1], hi)), fill: `url(#${id})` });
      if (r.rangeLabel) el(s, 'text', { x: W - 2, y: yy(Math.min(r.range[1], hi)) - 3, 'font-size': 8.5, fill: T3, 'text-anchor': 'end' }, r.rangeLabel);
    }
    (r.grid || []).forEach(g => { el(s, 'line', { x1: LAB, x2: W, y1: yy(g), y2: yy(g), stroke: LINE, 'stroke-width': .5, 'stroke-dasharray': '1 3' }); });
    const path = a => a.map((v, i) => (i ? 'L' : 'M') + cx(i) + ' ' + yy(v)).join(' ');
    if (r.band) el(s, 'path', { d: path(r.band) + ' ' + r.v.slice().reverse().map((v, j) => 'L' + cx(r.v.length - 1 - j) + ' ' + yy(v)).join(' ') + 'Z', fill: r.color, 'fill-opacity': .25 });
    (r.extra || []).forEach(e => el(s, 'path', { d: path(e.v), stroke: e.color, 'stroke-width': 1.6, fill: 'none', 'stroke-dasharray': e.dash || '', 'stroke-linejoin': 'round' }));
    el(s, 'path', { d: path(r.v), stroke: r.color, 'stroke-width': 2, fill: 'none', 'stroke-linejoin': 'round', 'stroke-linecap': 'round' });
    (r.labels || []).forEach(i => { el(s, 'circle', { cx: cx(i), cy: yy(r.v[i]), r: 3, fill: r.color, stroke: '#1E1B17', 'stroke-width': 1.5 });
      el(s, 'text', { x: cx(i), y: yy(r.v[i]) - 6, 'font-size': 10, fill: TXT, 'text-anchor': 'middle', 'font-weight': 600 }, (r.fmt || (v => v))(r.v[i])); });
    (r.notes || []).forEach(([i, t, dy]) => el(s, 'text', { x: cx(i), y: yy(r.v[i]) + (dy || 14), 'font-size': 9, fill: T2, 'text-anchor': 'middle' }, t));
  },
  bars(s, y, r) {
    const top = y + (r.lab ? 13 : 5), bot = y + r.h - 4;
    r.v.forEach((v, i) => { if (!v) return; const h = Math.max(2, v / r.max * (bot - top));
      el(s, 'rect', { x: cx(i) - CW * .32, y: bot - h, width: CW * .64, height: h, rx: 2.5, fill: r.color, 'fill-opacity': r.op ? r.op(v, i) : 1 });
      if (r.lab && (r.every ? i % r.every === 0 : true)) el(s, 'text', { x: cx(i), y: bot - h - 3, 'font-size': 8.5, fill: T2, 'text-anchor': 'middle' }, (r.fmt || (v => v))(v)); });
  },
  arrows(s, y, r) {
    r.v.forEach((d, i) => { if (r.every && i % r.every) return; const g = el(s, 'g', { transform: `translate(${cx(i)} ${y + (r.tags ? 11 : r.h / 2)}) rotate(${d + 180})` });
      el(g, 'path', { d: 'M0 -6 L0 6 M-3 2.5 L0 6 L3 2.5', stroke: r.color, 'stroke-width': 1.7, fill: 'none', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' });
      if (r.tags) { const t = r.tags[i], col = { off: '#CF3A78', on: T2, side: TXT, 'side-on': TXT, cross: T2 }[t] || T3;
        el(s, 'text', { x: cx(i), y: y + r.h - 4, 'font-size': 7.5, fill: col, 'text-anchor': 'middle', 'font-weight': t === 'off' ? 700 : 400 }, t === 'side-on' ? 'S-on' : t === 'side' ? 'side' : t); } });
  },
  nums(s, y, r) { r.v.forEach((v, i) => { if (r.every && i % r.every) return; el(s, 'text', { x: cx(i), y: y + r.h / 2 + 4, 'font-size': 10, fill: r.col ? r.col(v, i) : TXT, 'text-anchor': 'middle', 'font-weight': r.bold ? 600 : 400 }, (r.fmt || (v => v))(v)); }); },
  cat(s, y, r) {
    r.v.forEach((v, i) => { const c = r.map[v]; if (c) el(s, 'rect', { x: LAB + i * CW + 1, y: y + 5, width: CW - 2, height: r.h - 10, rx: 3, fill: c[0], 'fill-opacity': c[2] ?? 1 }); });
    r.v.forEach((v, i) => { const c = r.map[v]; if (!c || !c[1] || (i && r.v[i - 1] === v)) return; let run = 1; while (r.v[i + run] === v) run++;
      if (run >= 2) el(s, 'text', { x: LAB + i * CW + 4, y: y + r.h / 2 + 3.5, 'font-size': 8.5, fill: c[3] || '#15130F', 'font-weight': 600 }, c[1]); }); },
};

/* ---------- shared bits ---------- */
const days = (sel, ratings) => `<div class="tabs">${['Mon 9', 'Tue 10', 'Wed 11', 'Thu 12', 'Fri 13', 'Sat 14', 'Sun 15', 'Mon 16'].map((d, i) =>
  `<div class="tab ${i === sel ? 'on' : ''} ${i > 2 ? 'outlook' : ''}"><span>${d.split(' ')[0]}</span><b>${d.split(' ')[1]}</b><i style="background:${ratings[i] ? R[ratings[i] - 1] : '#2E2A24'}"></i></div>`).join('')}</div>
  <div class="faint" style="font-size:10.5px;margin:6px 2px 0">Hour by hour for 3 days · days 4–8 are a daily outlook</div>`;
const head = (sport, spot, back = 'Today') => `<div class="row muted" style="font-size:13px;gap:8px;margin-top:4px"><span style="font-size:18px">‹</span> ${back}</div>
  <div class="row" style="margin-top:8px"><div><div style="font-size:24px;font-weight:600;letter-spacing:-.01em">${sport}</div><div class="muted" style="font-size:13px;margin-top:1px">${spot}</div></div><div class="sp"></div>
  <span class="pill">Change spot</span></div>`;
const verdict = (r, word, best, line, conf) => `<div class="card verdict"><div class="row"><span class="dots big-dots">${dots(r)}</span><span style="margin-left:10px;font-weight:600;color:${R[r - 1]}">${word}</span><div class="sp"></div><span class="pill">${conf}</span></div>
  <div style="font-size:20px;font-weight:600;margin-top:10px;letter-spacing:-.01em">${best}</div><div class="muted" style="font-size:12.5px;margin-top:3px;line-height:1.45">${line}</div></div>`;
const sec = t => `<div class="lbl" style="margin:18px 0 8px">${t}</div>`;
const src = t => `<div class="src">Data: ${t}</div>`;
const fact = (l, v, s, col) => `<div class="fact"><div class="lbl">${l}</div><div class="v" style="${col ? 'color:' + col : ''}">${v}</div>${s ? `<div class="s">${s}</div>` : ''}</div>`;
const mgHost = id => `<div class="card mg" id="${id}"></div>`;
const warnLine = (lvl, t, d) => `<div class="warn w-${lvl}"><svg width="16" height="16" viewBox="0 0 24 24" style="flex:none;margin-top:1px"><path d="M12 3l10 18H2z" fill="var(--w-${lvl})"/><path d="M12 10v5M12 17.5v.5" stroke="#15130F" stroke-width="2" stroke-linecap="round"/></svg><div><div class="t">${t}</div><div class="d">${d}</div></div></div>`;
function small(id, w, h, fn) { const s = document.getElementById(id); s.setAttribute('width', w); s.setAttribute('height', h); fn(s); }

/* =====================================================================
   WING FOIL — Tue 10 Nov · Castelldefels (beach faces S)
   ===================================================================== */
document.getElementById('d-wing').innerHTML = head('Wing foil', 'Castelldefels · flatwater · beach faces S') + days(1, [3, 4, 2, 1, 1, 3, 4, 2]) +
  verdict(4, 'Good', 'Best 13–17 h · peak 14–16 h', 'Side-on SW building to 16–19 kn, gusts ≤ 24. Chop rising to 0.8 m. Morning offshore NW, so stay ashore before 10 h.', 'High confidence') +
  sec('Hour by hour') + mgHost('mg-wing') +
  `<div class="legend" style="margin-top:8px"><span><i class="sw" style="background:var(--wind);height:3px"></i>mean wind</span><span><i class="sw" style="background:color-mix(in srgb,var(--wind) 30%,transparent)"></i>gusts</span><span><i class="sw" style="background:repeating-linear-gradient(45deg,#3A342C 0 2px,transparent 2px 5px)"></i>your range</span><span><i class="sw" style="background:#1A1814;border:1px solid #36312A"></i>dark</span></div>` +
  sec('Gear for 75 kg') + `<div class="f2">${fact('Wing', '5 m → 4 m', '5 m 13–15 h · 4 m when gusts > 22')}${fact('Foil · board', '1100 cm² · 85 L', 'early-planing setup')}</div>` +
  sec('Forecast vs station today') + `<div class="card"><svg id="wing-bias"></svg><div class="legend" style="margin-top:6px"><span><i class="sw" style="background:var(--wind);height:3px"></i>measured · XEMA 10 m</span><span><i class="sw" style="background:repeating-linear-gradient(90deg,#B0A596 0 3px,transparent 3px 6px);height:2px"></i>Meteocat forecast</span></div>
    <div class="muted" style="font-size:12px;margin-top:8px;line-height:1.45">Running <b style="color:${TXT}">+2 kn above forecast</b> today. In SW over the last 30 days the forecast here averaged 1.8 kn low, so corrected values are shown above.</div></div>` +
  sec('Pressure · next front') + `<div class="card"><svg id="wing-press"></svg><div class="muted" style="font-size:12px;margin-top:6px">Falling 4 hPa in 6 h. Front on Wed: NW gusts 30+ kn (offshore), so Wed is not rideable.</div></div>` +
  sec('Water · light · safety') + `<div class="f4">${fact('Water', '18.6°', '3/2 suit')}${fact('Sunset', '17:35', 'last light 18:03')}${fact('Lightning', 'none', '50 km · 24 h')}${fact('UV max', '2', 'low')}</div>
   <div class="card row" style="margin-top:10px;gap:10px;padding:12px 14px"><span style="color:var(--w-yellow)">▲</span><div style="font-size:12px" class="muted"><b style="color:${TXT}">Pre-warning Wed:</b> yellow wind warning likely for the Barcelona coast.</div></div>` +
  src('beach forecast Castelldefels (hourly wind, waves, water), XEMA 30/31/50 + 34 (pressure), municipal hourly, UV, XDDE, warnings and pre-warnings, Open-Meteo gust forecast');

meteogram(document.getElementById('mg-wing'), [
  { type: 'icons', label: 'Sky', h: 26, v: ['partly', 'sun', 'sun', 'sun', 'sun', 'partly', 'partly', 'partly', 'partly', 'cloud', 'cloud', 'night', 'night', 'night'] },
  { type: 'rating', label: 'Rating', h: 22, v: [0, 0, 0, 1, 2, 3, 4, 5, 5, 4, 2, 0, 0, 0] },
  { type: 'line', label: 'Wind', unit: 'kn', h: 96, min: 0, max: 30, color: C('--wind'), range: [14, 24], rangeLabel: 'your range 14–24',
    v: [6, 7, 8, 10, 12, 14, 16, 18, 19, 18, 16, 13, 10, 8], band: [9, 10, 11, 13, 16, 18, 21, 23, 24, 23, 21, 17, 14, 11], labels: [8], grid: [10, 20] },
  { type: 'arrows', label: 'From', unit: 'vs shore', h: 32, color: C('--wind'), v: [320, 320, 300, 260, 240, 230, 225, 225, 220, 220, 225, 230, 240, 260],
    tags: ['off', 'off', 'off', 'side', 'side', 'side-on', 'side-on', 'side-on', 'side-on', 'side-on', 'side-on', 'side-on', 'side', 'side'] },
  { type: 'nums', label: 'Gust', unit: 'kn', h: 22, v: [9, 10, 11, 13, 16, 18, 21, 23, 24, 23, 21, 17, 14, 11], col: v => v > 22 ? C('--heat') : T2 },
  { type: 'bars', label: 'Waves', unit: 'm', h: 38, max: 1.2, color: C('--wave'), lab: true, every: 2, fmt: v => v.toFixed(1), v: [.3, .3, .3, .4, .4, .5, .6, .7, .8, .8, .8, .7, .7, .6] },
  { type: 'nums', label: 'Air', unit: '°C', h: 22, every: 1, v: [12, 13, 15, 17, 18, 19, 19, 19, 18, 17, 16, 15, 14, 14], fmt: v => v + '°', col: () => C('--heat') },
  { type: 'bars', label: 'Rain', unit: '%', h: 30, max: 100, color: C('--rain'), lab: true, every: 2, fmt: v => v, v: [0, 0, 0, 0, 0, 5, 5, 10, 10, 20, 30, 40, 30, 20] },
  { type: 'cat', label: 'Storm', h: 22, v: Array(14).fill('none'), map: { none: ['#24201B', 'no lightning risk all day', 1, T3] } },
], { best: [13, 17] });

small('wing-bias', 322, 96, s => { const f = [6, 7, 8, 10, 12, 14, 16, 18], m = [7, 9, 10, 12, 14, 16], x = i => 30 + i * 40, y = v => 84 - v / 22 * 74;
  [0, 10, 20].forEach(g => { el(s, 'line', { x1: 24, x2: 322, y1: y(g), y2: y(g), stroke: LINE, 'stroke-width': .5 }); el(s, 'text', { x: 0, y: y(g) + 3, 'font-size': 9, fill: T3 }, g); });
  el(s, 'path', { d: f.map((v, i) => (i ? 'L' : 'M') + x(i) + ' ' + y(v)).join(' '), stroke: T2, 'stroke-dasharray': '3 3', 'stroke-width': 1.6, fill: 'none' });
  el(s, 'path', { d: m.map((v, i) => (i ? 'L' : 'M') + x(i) + ' ' + y(v)).join(' '), stroke: C('--wind'), 'stroke-width': 2, fill: 'none' });
  el(s, 'circle', { cx: x(5), cy: y(16), r: 3.5, fill: C('--wind'), stroke: '#1E1B17', 'stroke-width': 1.5 });
  el(s, 'text', { x: x(5), y: y(16) - 7, 'font-size': 10, fill: TXT, 'text-anchor': 'middle', 'font-weight': 600 }, 'now 16');
  ['07', '09', '11', '13'].forEach((t, k) => el(s, 'text', { x: x(k * 2), y: 96, 'font-size': 9, fill: T3, 'text-anchor': 'middle' }, t)); });
small('wing-press', 322, 70, s => { const v = [1018, 1018, 1017.5, 1017, 1016, 1015, 1014, 1013, 1012, 1011, 1010, 1009.5, 1009], x = i => 6 + i * 24, y = p => 58 - (p - 1008) / 11 * 50;
  el(s, 'line', { x1: x(6), x2: x(6), y1: 4, y2: 62, stroke: LINE, 'stroke-dasharray': '2 2' }); el(s, 'text', { x: x(6) + 4, y: 12, 'font-size': 9, fill: T3 }, 'now');
  el(s, 'path', { d: v.map((p, i) => (i ? 'L' : 'M') + x(i) + ' ' + y(p)).join(' '), stroke: T2, 'stroke-width': 2, fill: 'none' });
  el(s, 'text', { x: x(0), y: y(1018) - 6, 'font-size': 10, fill: TXT }, '1018'); el(s, 'text', { x: x(12), y: y(1009) - 6, 'font-size': 10, fill: TXT, 'text-anchor': 'end' }, '1009 hPa');
  el(s, 'text', { x: 0, y: 70, 'font-size': 9, fill: T3 }, '−12 h'); el(s, 'text', { x: 322, y: 70, 'font-size': 9, fill: T3, 'text-anchor': 'end' }, '+12 h'); });

/* =====================================================================
   SURF — Wed 11 Nov · Ocata (faces E–SE, exposure 40–180°)
   ===================================================================== */
document.getElementById('d-surf').innerHTML = head('Surf', 'Ocata · El Masnou · faces E–SE') + days(2, [1, 1, 3, 4, 3, 1, 1, 2]) +
  verdict(3, 'Fair', 'Best 08–11 h · dawn patrol', 'E swell 1.1–1.2 m @ 9 s, direct hit. Light W offshore until 10 h, then the sea breeze turns onshore and it gets choppy after noon.', 'Medium confidence') +
  warnLine('orange', 'Orange warning · Sea state', 'Maresme coast · Wed 12–20 h · waves up to 2.5 m offshore') +
  sec('Hour by hour') + mgHost('mg-surf') +
  sec('Swell window') + `<div class="row" style="gap:12px"><div class="card" style="padding:10px"><svg id="surf-win"></svg></div>
    <div style="flex:1;display:flex;flex-direction:column;gap:8px">${fact('Swell', 'E 95°', 'inside window 40–180°')}${fact('Energy', 'building', '+0.4 m in 24 h')}</div></div>` +
  sec('Buoy · last 24 h') + `<div class="card"><svg id="surf-buoy"></svg><div class="legend" style="margin-top:6px"><span><i class="sw" style="background:var(--wave)"></i>significant height</span><span>period labelled</span></div></div>` +
  sec('Body') + `<div class="f4">${fact('Water', '19.2°', '3/2 full')}${fact('Air', '12→18°', 'cold dawn')}${fact('UV max', '2', 'low')}${fact('Sunrise', '07:37', 'first light 07:09')}</div>` +
  src('beach forecast Ocata (hourly waves, direction, water temp), XEMA buoy 90–97, municipal hourly wind, warnings, Open-Meteo Marine (swell period forecast)');

meteogram(document.getElementById('mg-surf'), [
  { type: 'icons', label: 'Sky', h: 26, v: ['sun', 'sun', 'sun', 'sun', 'partly', 'partly', 'cloud', 'cloud', 'cloud', 'rain', 'rain', 'night', 'night', 'night'] },
  { type: 'rating', label: 'Rating', h: 22, v: [2, 3, 4, 4, 3, 2, 2, 1, 1, 1, 1, 0, 0, 0] },
  { type: 'bars', label: 'Waves', unit: 'm', h: 78, max: 1.5, color: C('--wave'), lab: true, every: 1, fmt: v => v.toFixed(1), v: [.9, 1, 1.1, 1.2, 1.2, 1.2, 1.1, 1.1, 1, 1, .9, .9, .8, .8], op: (v, i) => i >= 1 && i <= 3 ? 1 : .55 },
  { type: 'nums', label: 'Period', unit: 's', h: 22, v: [8, 8, 9, 9, 9, 9, 9, 8, 8, 8, 8, 7, 7, 7], col: v => v >= 9 ? TXT : T2, bold: true },
  { type: 'arrows', label: 'Swell', h: 24, color: C('--wave'), v: Array(14).fill(95), every: 2 },
  { type: 'arrows', label: 'Wind', unit: 'vs beach', h: 32, color: C('--wind'), v: [300, 300, 290, 270, 200, 150, 120, 110, 100, 100, 90, 80, 60, 40],
    tags: ['off', 'off', 'off', 'off', 'cross', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on', 'on'] },
  { type: 'nums', label: 'Wind', unit: 'kn', h: 22, v: [6, 6, 5, 4, 4, 6, 9, 11, 12, 12, 11, 9, 8, 7], col: v => v > 10 ? C('--heat') : T2 },
  { type: 'nums', label: 'Air', unit: '°C', h: 22, v: [10, 11, 12, 14, 16, 17, 18, 18, 17, 16, 15, 14, 13, 13], fmt: v => v + '°', col: () => C('--heat') },
  { type: 'bars', label: 'Rain', unit: '%', h: 30, max: 100, color: C('--rain'), lab: true, every: 2, v: [0, 0, 0, 0, 0, 10, 20, 30, 40, 60, 60, 40, 20, 10] },
], { best: [8, 11], sunrise: 7.62 });

small('surf-win', 140, 140, s => { const c = 70, r = 58, P = a => [c + r * Math.sin(a * Math.PI / 180), c - r * Math.cos(a * Math.PI / 180)];
  const [x0, y0] = P(40), [x1, y1] = P(180); el(s, 'path', { d: `M${c} ${c} L${x0} ${y0} A${r} ${r} 0 0 1 ${x1} ${y1} Z`, fill: C('--wave'), 'fill-opacity': .14 });
  el(s, 'circle', { cx: c, cy: c, r, fill: 'none', stroke: LINE });
  [['N', 0], ['E', 90], ['S', 180], ['W', 270]].forEach(([t, a]) => { const [x, y] = [c + (r - 11) * Math.sin(a * Math.PI / 180), c - (r - 11) * Math.cos(a * Math.PI / 180)]; el(s, 'text', { x, y: y + 3.5, 'font-size': 9.5, fill: T3, 'text-anchor': 'middle' }, t); });
  const g = el(s, 'g', { transform: `rotate(${95 - 90} ${c} ${c})` });
  el(g, 'path', { d: `M${c + 50} ${c} L${c + 8} ${c} M${c + 16} ${c - 6} L${c + 7} ${c} L${c + 16} ${c + 6}`, stroke: C('--wave'), 'stroke-width': 2.6, fill: 'none', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' });
  const [a1, b1] = P(20), [a2, b2] = P(200); el(s, 'line', { x1: a1, y1: b1, x2: a2, y2: b2, stroke: '#D9B98A', 'stroke-dasharray': '3 3' });
  el(s, 'circle', { cx: c, cy: c, r: 3, fill: '#D9B98A' }); el(s, 'text', { x: 4, y: 138, 'font-size': 9, fill: T3 }, 'shaded = open to the sea'); });
small('surf-buoy', 322, 100, s => { const v = [.5, .5, .55, .6, .6, .65, .7, .7, .75, .8, .8, .85, .9], p = [6, 6, 6, 7, 7, 7, 7, 8, 8, 8, 8, 9, 9], x = i => 8 + i * 25, y = h => 84 - h / 1.2 * 70;
  v.forEach((h, i) => { el(s, 'rect', { x: x(i) - 8, y: y(h), width: 16, height: 84 - y(h), rx: 3, fill: C('--wave'), 'fill-opacity': i === 12 ? 1 : .55 }); if (i % 3 === 0 || i === 12) el(s, 'text', { x: x(i), y: y(h) - 4, 'font-size': 9, fill: i === 12 ? TXT : T2, 'text-anchor': 'middle' }, p[i] + 's'); });
  el(s, 'line', { x1: 0, x2: 322, y1: 84, y2: 84, stroke: LINE }); el(s, 'text', { x: 0, y: 98, 'font-size': 9, fill: T3 }, '−24 h'); el(s, 'text', { x: 322, y: 98, 'font-size': 9, fill: T3, 'text-anchor': 'end' }, 'now 0.9 m'); });

/* =====================================================================
   BIKE — Mon 9 Nov · Collserola loop 42 km / 3 h
   ===================================================================== */
document.getElementById('d-bike').innerHTML = head('Bike', 'Collserola loop · 42 km · 780 m ↑') + days(0, [4, 3, 1, 3, 4, 5, 4, 3]) +
  verdict(5, 'Epic', 'Leave 09:00 → back 12:00', 'Dry window before the 13 h showers. NW tailwind on the climb, roads dry from 09 h. Feels 11° at the start, 19° at the finish.', 'High confidence') +
  `<div class="card row" style="margin-top:10px;gap:10px;padding:12px 14px"><div class="lbl" style="margin:0">Ride length</div><div class="sp"></div>${['1 h', '2 h', '3 h', '4 h', '5 h'].map(t => `<span class="chip ${t === '3 h' ? 'on' : ''}" style="padding:5px 10px">${t}</span>`).join('')}</div>` +
  sec('Hour by hour') + mgHost('mg-bike') +
  sec('Wind along the route · leaving 09:00') + `<div class="card"><svg id="bike-route"></svg><div class="legend" style="margin-top:6px"><span><i class="sw" style="background:var(--wind)"></i>tailwind</span><span><i class="sw" style="background:#7E7468"></i>crosswind</span><span><i class="sw" style="background:var(--heat)"></i>headwind</span></div></div>` +
  sec('Surface') + `<div class="f2">${fact('Roads', 'dry from 09 h', '3.2 mm overnight · drying fast')}${fact('Gravel · trails', 'damp', '6 mm in 72 h · ET₀ 1.4 mm/day · soil 31 %')}</div>` +
  sec('What to wear') + `<div class="card" style="font-size:13px;line-height:1.6"><b>Start 11° feels-like · 6 kn NW</b><br><span class="muted">Long-finger gloves and a gilet until 10 h; arm warmers you can pocket. Rain jacket stays home if you're back by 12:30.</span></div>` +
  src('municipal hourly (temp, rain, wind, sky), XEMA 35/70/72 (rain observed, intensity), 11–13 (asphalt temp → ice), 62/63 (soil moisture), CMV 6006 (ET₀), UV forecast, warnings');

meteogram(document.getElementById('mg-bike'), [
  { type: 'icons', label: 'Sky', h: 26, v: ['partly', 'sun', 'sun', 'sun', 'partly', 'cloud', 'rain', 'rain', 'rain', 'cloud', 'partly', 'night', 'night', 'night'] },
  { type: 'rating', label: 'Rating', h: 22, v: [1, 2, 4, 5, 5, 4, 2, 1, 1, 2, 2, 1, 0, 0] },
  { type: 'line', label: 'Temp', unit: '°C', h: 80, min: 6, max: 22, color: C('--heat'), v: [9, 10, 12, 14, 16, 18, 19, 20, 20, 19, 17, 15, 14, 13], labels: [0, 7],
    fmt: v => v + '°', extra: [{ v: [7, 8, 11, 13, 15, 17, 18, 19, 19, 18, 16, 14, 12, 11], color: C('--heat'), dash: '2 3' }], notes: [[3, 'feels (dashed)', 22]], grid: [10, 15, 20] },
  { type: 'bars', label: 'Rain', unit: 'mm', h: 40, max: 3, color: C('--rain'), lab: true, fmt: v => v.toFixed(1), v: [0, 0, 0, 0, 0, 0, .4, 2.1, 1.6, .3, 0, 0, 0, 0] },
  { type: 'nums', label: 'Chance', unit: '%', h: 22, v: [0, 0, 0, 0, 0, 10, 30, 60, 60, 40, 20, 10, 0, 0], col: v => v >= 30 ? C('--rain') : T3 },
  { type: 'cat', label: 'Roads', h: 22, v: ['wet', 'damp', 'dry', 'dry', 'dry', 'dry', 'damp', 'wet', 'wet', 'wet', 'damp', 'damp', 'dry', 'dry'],
    map: { wet: [C('--rain'), 'wet', .9], damp: [C('--rain'), 'damp', .45], dry: ['#2A261F', '', 1] } },
  { type: 'arrows', label: 'Wind', h: 24, color: C('--wind'), v: [330, 330, 320, 300, 250, 230, 225, 225, 230, 240, 260, 300, 320, 330] },
  { type: 'nums', label: 'Speed', unit: 'kn', h: 22, v: [5, 5, 6, 7, 8, 10, 12, 14, 13, 11, 9, 7, 6, 5], col: v => v > 12 ? C('--heat') : T2 },
  { type: 'bars', label: 'UV', h: 30, max: 6, color: C('--sun'), lab: true, v: [0, 0, 1, 2, 3, 3, 3, 2, 1, 1, 0, 0, 0, 0] },
], { best: [9, 12] });

small('bike-route', 322, 150, s => { // loop polyline with segment colours by headwind/tailwind at NW 300°
  const pts = [[40, 120], [70, 95], [95, 70], [130, 45], [175, 30], [220, 28], [262, 42], [285, 70], [280, 102], [250, 122], [205, 132], [150, 135], [100, 132], [60, 128], [40, 120]];
  const wind = 300; // from
  for (let i = 0; i < pts.length - 1; i++) { const [a, b] = [pts[i], pts[i + 1]]; const bearing = (Math.atan2(b[0] - a[0], a[1] - b[1]) * 180 / Math.PI + 360) % 360;
    const rel = Math.cos((bearing - (wind + 180)) * Math.PI / 180); const col = rel > .35 ? C('--wind') : rel < -.35 ? C('--heat') : '#7E7468';
    el(s, 'line', { x1: a[0], y1: a[1], x2: b[0], y2: b[1], stroke: col, 'stroke-width': 5, 'stroke-linecap': 'round' }); }
  el(s, 'circle', { cx: 40, cy: 120, r: 5, fill: TXT }); el(s, 'text', { x: 50, y: 142, 'font-size': 9.5, fill: T2 }, 'start · Sarrià');
  el(s, 'text', { x: 175, y: 20, 'font-size': 9.5, fill: T2 }, 'Tibidabo 512 m');
  const g = el(s, 'g', { transform: `translate(300 22) rotate(${wind + 180})` }); el(g, 'path', { d: 'M0 -9 L0 9 M-4 4 L0 9 L4 4', stroke: C('--wind'), 'stroke-width': 2, fill: 'none', 'stroke-linecap': 'round' });
  el(s, 'text', { x: 300, y: 46, 'font-size': 9, fill: T2, 'text-anchor': 'middle' }, 'NW 7 kn');
  el(s, 'text', { x: 0, y: 12, 'font-size': 11, fill: TXT, 'font-weight': 600 }, '58 % tailwind on the climb'); });

/* =====================================================================
   RUN — Tue 10 Nov · Barcelona · 1 h
   ===================================================================== */
document.getElementById('d-run').innerHTML = head('Run', 'Barcelona · Diagonal Mar · 10 km') + days(1, [3, 4, 2, 3, 4, 5, 4, 3]) +
  verdict(4, 'Good', 'Best 08:00–09:00 · or after 18 h', 'Feels 11–13° with low UV and dry streets in the morning. Midday reaches 21° feels-like in full sun with UV 3, and humidity climbs again after dark.', 'High confidence') +
  `<div class="card row" style="margin-top:10px;gap:10px;padding:12px 14px"><div class="lbl" style="margin:0">Run length</div><div class="sp"></div>${['30 min', '1 h', '1.5 h', '2 h+'].map(t => `<span class="chip ${t === '1 h' ? 'on' : ''}" style="padding:5px 10px">${t}</span>`).join('')}</div>` +
  sec('Hour by hour') + mgHost('mg-run') +
  sec('Sun or shade') + `<div class="f2">${fact('In full sun', '+3 °C', '480 W/m² at 12 h')}${fact('Shade route', 'Parc del Fòrum', 'suggested 11–15 h')}</div>` +
  sec('Body') + `<div class="f4">${fact('Wear', 'Long sleeve', 'shorts')}${fact('Drink', '0.4 L', 'low sweat')}${fact('Heat stress', 'low', 'all day')}${fact('Air', 'AQI 32', 'good · optional')}</div>` +
  src('municipal hourly (temp, feels, RH, rain, wind), UV forecast, XEMA 32/33 (now), 36 (irradiance), 39 (UV measured), warnings; air quality optional via Open-Meteo');

meteogram(document.getElementById('mg-run'), [
  { type: 'icons', label: 'Sky', h: 26, v: ['partly', 'sun', 'sun', 'sun', 'sun', 'sun', 'partly', 'partly', 'partly', 'cloud', 'cloud', 'night', 'night', 'night'] },
  { type: 'rating', label: 'Rating', h: 22, v: [3, 5, 5, 4, 3, 2, 2, 2, 2, 3, 3, 4, 4, 3] },
  { type: 'line', label: 'Feels', unit: '°C', h: 84, min: 6, max: 24, color: C('--heat'), range: [6, 16], rangeLabel: 'comfort 6–16°',
    v: [10, 11, 13, 15, 17, 19, 20, 21, 21, 20, 18, 16, 15, 14], labels: [1, 7], fmt: v => v + '°', grid: [10, 20] },
  { type: 'nums', label: 'Humid.', unit: '%', h: 22, v: [88, 85, 78, 70, 62, 55, 52, 50, 52, 58, 65, 72, 78, 82], col: v => v > 80 ? C('--rain') : T2 },
  { type: 'bars', label: 'UV', h: 34, max: 6, color: C('--sun'), lab: true, v: [0, 0, 1, 2, 3, 3, 3, 2, 1, 1, 0, 0, 0, 0] },
  { type: 'bars', label: 'Sun', unit: 'W/m²', h: 34, max: 600, color: C('--sun'), op: () => .45, v: [0, 40, 180, 320, 430, 480, 470, 400, 280, 140, 30, 0, 0, 0] },
  { type: 'bars', label: 'Rain', unit: '%', h: 28, max: 100, color: C('--rain'), lab: true, every: 2, v: [0, 0, 0, 0, 0, 0, 5, 5, 10, 10, 10, 5, 0, 0] },
  { type: 'nums', label: 'Wind', unit: 'kn', h: 22, v: [4, 5, 6, 7, 9, 11, 12, 13, 12, 10, 8, 6, 5, 4], col: () => T2 },
], { best: [8, 9] });

/* =====================================================================
   HIKE — Sat 14 Nov · Pedraforca 2506 m from Refugi Lluís Estasen 1640 m
   ===================================================================== */
document.getElementById('d-hike').innerHTML = head('Hike', 'Pedraforca 2506 m · from refugi 1640 m') + days(2, [2, 2, 3, 3, 3, 3, 4, 2]) +
  verdict(3, 'Fair', 'Start 07:30 · turn back by 12:00', 'Clear, cold morning, -1° and NW 22 kn on the summit. Cumulus builds from 12 h, with a 45 % storm risk at 14 h. Be down at the refugi before 14 h.', 'Medium confidence') +
  sec('Plan') + `<div class="card"><svg id="hike-plan"></svg></div>` +
  sec('Summit hour by hour') + mgHost('mg-hike') +
  sec('Temperature by altitude · 11 h') + `<div class="card"><svg id="hike-alt"></svg></div>` +
  sec('Snow · lightning · ground') + `<div class="f2"><div class="card" style="padding:12px"><div class="lbl">Snow depth · Cadí station 2140 m</div><svg id="hike-snow"></svg></div>
    <div class="card" style="padding:12px"><div class="lbl">Lightning · Berguedà · 5 days</div><svg id="hike-light"></svg></div></div>
   <div class="f2" style="margin-top:10px">${fact('North faces', 'icy', 'snow level 2300 m · −1° summit')}${fact('Daylight', '07:58–17:24', '9 h 26 min')}</div>` +
  src('Pyrenees summit forecast (pics/el-pedraforca), refugi forecast, Pyrenees area forecast, XEMA 38 (snow), 32 (mountain stations), XDDE county report + live strikes, warnings; freezing level via Open-Meteo');

meteogram(document.getElementById('mg-hike'), [
  { type: 'icons', label: 'Sky', h: 26, v: ['sun', 'sun', 'sun', 'sun', 'partly', 'cloud', 'storm', 'storm', 'storm', 'rain', 'cloud', 'night', 'night', 'night'] },
  { type: 'rating', label: 'Rating', h: 22, v: [2, 4, 5, 5, 4, 3, 1, 1, 1, 1, 1, 0, 0, 0] },
  { type: 'bars', label: 'Storm', unit: '%', h: 40, max: 70, color: C('--storm'), lab: true, every: 1, v: [0, 0, 0, 0, 5, 10, 25, 45, 60, 55, 40, 20, 10, 0] },
  { type: 'line', label: 'Wind', unit: 'kn', h: 70, min: 0, max: 45, color: C('--wind'), v: [22, 24, 22, 18, 15, 14, 16, 20, 25, 28, 30, 30, 28, 26],
    band: [31, 34, 31, 25, 21, 20, 22, 28, 35, 39, 42, 42, 39, 36], labels: [1, 10], grid: [20, 40] },
  { type: 'nums', label: 'Temp', unit: '°C', h: 22, v: [-2, -1, 0, 2, 3, 4, 4, 3, 2, 1, 0, -1, -2, -2], fmt: v => v + '°', col: v => v <= 0 ? C('--snow') : C('--heat') },
  { type: 'bars', label: 'Precip', unit: 'mm', h: 32, max: 3, color: C('--rain'), lab: true, fmt: v => v.toFixed(1), v: [0, 0, 0, 0, 0, 0, .5, 1.8, 2.4, 1.2, .3, 0, 0, 0] },
  { type: 'nums', label: 'Snow lvl', unit: 'm', h: 32, every: 2, v: [2300, 2300, 2350, 2400, 2400, 2400, 2350, 2300, 2200, 2100, 2000, 1900, 1900, 1900], col: () => C('--snow') },
], { best: [7.5, 12], sunrise: 7.97, sunset: 17.4 });

small('hike-plan', 322, 66, s => { const x = h => 10 + (h - 7) * 28.5; // 7..18
  el(s, 'rect', { x: x(7), y: 22, width: x(18) - x(7), height: 10, rx: 5, fill: '#24201B' });
  el(s, 'rect', { x: x(7.97), y: 22, width: x(17.4) - x(7.97), height: 10, rx: 5, fill: '#2E2A24' });
  [[7.5, 10.75, R[4], 'up'], [10.75, 11.25, R[3], ''], [11.25, 13.75, R[3], 'down']].forEach(([a, b, c, t]) => { el(s, 'rect', { x: x(a), y: 22, width: x(b) - x(a), height: 10, rx: 5, fill: c }); if (t) el(s, 'text', { x: (x(a) + x(b)) / 2, y: 30, 'font-size': 8, fill: '#15130F', 'text-anchor': 'middle', 'font-weight': 700 }, t); });
  el(s, 'rect', { x: x(13), y: 20, width: x(17) - x(13), height: 14, rx: 4, fill: C('--storm'), 'fill-opacity': .25 });
  [[7.5, 'start 07:30'], [10.75, 'summit 10:45'], [12, 'turn-back limit 12:00'], [13.75, 'refugi 13:45']].forEach(([h, t], k) => { el(s, 'line', { x1: x(h), x2: x(h), y1: k % 2 ? 34 : 16, y2: k % 2 ? 44 : 22, stroke: h === 12 ? C('--w-orange') : T2 });
    el(s, 'text', { x: x(h), y: k % 2 ? 55 : 11, 'font-size': 9.5, fill: h === 12 ? C('--w-orange') : TXT, 'text-anchor': 'middle', 'font-weight': h === 12 ? 600 : 400 }, t); });
  el(s, 'text', { x: x(17), y: 64, 'font-size': 9, fill: C('--storm'), 'text-anchor': 'end' }, 'storm risk 13–17 h'); });
small('hike-alt', 322, 150, s => { s.style.overflow = 'visible'; const pts = [[1215, 7, 'Saldes'], [1640, 5, 'Refugi'], [2100, 2, ''], [2506, -1, 'Summit']], x = t => 40 + (t + 4) / 16 * 270, y = a => 136 - (a - 1000) / 1700 * 124;
  [1500, 2000, 2500].forEach(a => { el(s, 'line', { x1: 34, x2: 322, y1: y(a), y2: y(a), stroke: LINE, 'stroke-width': .5 }); el(s, 'text', { x: 0, y: y(a) + 3, 'font-size': 9, fill: T3 }, a + ' m'); });
  el(s, 'line', { x1: x(0), x2: x(0), y1: 6, y2: 140, stroke: C('--snow'), 'stroke-dasharray': '2 3' }); el(s, 'text', { x: x(0) + 4, y: 140, 'font-size': 9, fill: C('--snow') }, '0 °C');
  el(s, 'line', { x1: 34, x2: 322, y1: y(2300), y2: y(2300), stroke: C('--snow'), 'stroke-opacity': .6 }); el(s, 'text', { x: 322, y: y(2300) - 4, 'font-size': 9, fill: C('--snow'), 'text-anchor': 'end' }, 'snow level 2300 m');
  el(s, 'path', { d: pts.map((p, i) => (i ? 'L' : 'M') + x(p[1]) + ' ' + y(p[0])).join(' '), stroke: C('--heat'), 'stroke-width': 2, fill: 'none' });
  pts.forEach(([a, t, n]) => { el(s, 'circle', { cx: x(t), cy: y(a), r: 3.5, fill: C('--heat'), stroke: '#1E1B17', 'stroke-width': 1.5 }); if (n) el(s, 'text', { x: x(t) + 8, y: y(a) + (a > 2400 ? -7 : 4), 'font-size': 10, fill: TXT }, `${n} ${t}°`); }); });
small('hike-snow', 140, 64, s => { const v = [0, 0, 0, 2, 4, 4, 4, 3, 3, 6, 10, 12, 12, 12], x = i => 4 + i * 10, y = c => 50 - c / 14 * 40;
  el(s, 'path', { d: v.map((c, i) => (i ? 'L' : 'M') + x(i) + ' ' + y(c)).join(' ') + ` L${x(13)} 50 L${x(0)} 50 Z`, fill: C('--snow'), 'fill-opacity': .2 });
  el(s, 'path', { d: v.map((c, i) => (i ? 'L' : 'M') + x(i) + ' ' + y(c)).join(' '), stroke: C('--snow'), 'stroke-width': 2, fill: 'none' });
  el(s, 'text', { x: 136, y: y(12) - 5, 'font-size': 11, fill: TXT, 'text-anchor': 'end', 'font-weight': 600 }, '12 cm'); el(s, 'text', { x: 0, y: 62, 'font-size': 8.5, fill: T3 }, '14 days'); });
small('hike-light', 140, 64, s => { const v = [0, 0, 14, 37, 3], n = ['Thu', 'Fri', 'Sat', 'Sun', 'Mon'];
  v.forEach((k, i) => { const h = k / 40 * 36; if (k) el(s, 'rect', { x: 6 + i * 27, y: 46 - h, width: 18, height: h, rx: 3, fill: C('--storm') }); el(s, 'text', { x: 15 + i * 27, y: 58, 'font-size': 8.5, fill: T3, 'text-anchor': 'middle' }, n[i]); if (k) el(s, 'text', { x: 15 + i * 27, y: 42 - h, 'font-size': 9, fill: T2, 'text-anchor': 'middle' }, k); });
  el(s, 'line', { x1: 0, x2: 140, y1: 46, y2: 46, stroke: LINE }); });
