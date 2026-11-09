import { Fragment, type ReactElement } from 'react';
import { colors, accentColor, ratingColor, type Accent } from '../tokens';
import { linePath, bandPath, uid } from '../svg';
import { WeatherIcon, type WeatherKind } from '../components/WeatherIcon';

export type ShoreRelation = 'off' | 'side' | 'side-on' | 'on' | 'cross';

export type HourRow =
  | { type: 'icons'; label: string; values: WeatherKind[] }
  | { type: 'rating'; label: string; values: number[] }
  | { type: 'line'; label: string; unit?: string; values: number[]; min: number; max: number; accent: Accent;
      /** Upper band, e.g. gusts above mean wind. */ band?: number[];
      /** Dashed companion series in the same unit, e.g. feels-like. */ companion?: number[];
      /** Hatched preferred range, e.g. your wind range [14, 24]. */ range?: [number, number]; rangeLabel?: string;
      /** Indexes to label with their value. */ labelAt?: number[]; height?: number }
  | { type: 'bars'; label: string; unit?: string; values: number[]; max: number; accent: Accent;
      /** Print values above bars (every Nth). */ labelEvery?: number; decimals?: number; highlight?: number[]; height?: number }
  | { type: 'arrows'; label: string; unit?: string; /** Direction FROM, degrees. */ directions: number[]; accent: Accent; shore?: ShoreRelation[]; every?: number }
  | { type: 'numbers'; label: string; unit?: string; values: number[]; suffix?: string; every?: number;
      /** Values above this are drawn in the warning-free emphasis colour. */ emphasizeAbove?: number; accent?: Accent }
  | { type: 'category'; label: string; values: string[]; styles: Record<string, { color: string; opacity?: number; text?: string; textColor?: string }> };

export interface HourChartProps {
  /** Column hours, e.g. [7, 8, …, 20]. */
  hours: number[];
  rows: HourRow[];
  /** Recommended window [startHour, endHour] — drawn as a dashed frame. */
  best?: [number, number];
  /** Decimal hours; columns outside daylight are shaded. */
  sunrise?: number;
  sunset?: number;
  width?: number;
}

const ROWH: Record<HourRow['type'], number> = { icons: 26, rating: 22, line: 84, bars: 34, arrows: 24, numbers: 22, category: 22 };

/**
 * The planner meteogram: every variable as one row on shared hour columns, with night shading and the best window framed.
 * Compose rows per sport (e.g. wing: icons, rating, wind line with gust band and your range, arrows with shore relation, gusts, waves, air, rain).
 */
export function HourChart({ hours, rows, best, sunrise = 7.6, sunset = 17.6, width = 326 }: HourChartProps) {
  const LAB = 54, CW = (width - LAB) / hours.length, h0 = hours[0];
  const cx = (i: number) => LAB + i * CW + CW / 2, hx = (h: number) => LAB + (h - h0) * CW;
  // Units sit inline after short labels ("Gust kn"); longer label+unit pairs go on a second line and the row grows to fit.
  const inline = (r: HourRow) => 'unit' in r && !!r.unit && (r.type === 'numbers' || (r.type === 'arrows' && !r.shore)) && r.label.length + r.unit.length <= 8;
  const heights = rows.map(r => {
    const base = ('height' in r && r.height) || ROWH[r.type];
    return 'unit' in r && r.unit && !inline(r) ? Math.max(base, 32) : base;
  });
  const total = 18 + heights.reduce((a, b) => a + b, 0);
  const ys: number[] = []; heights.reduce((y, h) => (ys.push(y), y + h), 18);
  const hatch = uid('og-hatch');
  const out: ReactElement[] = [];

  rows.forEach((r, k) => {
    const y = ys[k], h = heights[k];
    const inlineUnit = inline(r);
    const ly = y + Math.min(h / 2 + 4, 15);
    out.push(<Fragment key={'l' + k}>
      {k > 0 && <line x1={0} x2={width} y1={y} y2={y} stroke={colors.line} strokeWidth={0.6} />}
      <text x={0} y={ly} fontSize={10} fill={colors.text2} fontWeight={500}>{r.label}{'unit' in r && r.unit && inlineUnit && <tspan fontSize={8.5} fill={colors.text3} fontWeight={400} dx={3}>{r.unit}</tspan>}</text>
      {'unit' in r && r.unit && !inlineUnit && <text x={0} y={ly + 11} fontSize={8.5} fill={colors.text3}>{r.unit}</text>}
    </Fragment>);
    const g: ReactElement[] = [];
    if (r.type === 'icons') r.values.forEach((v, i) => i % 2 === 0 && g.push(<g key={i} transform={`translate(${cx(i) - 9} ${y + 3}) scale(.75)`}><WeatherIcon kind={v} size={24} /></g>));
    if (r.type === 'rating') r.values.forEach((v, i) => g.push(<rect key={i} x={LAB + i * CW + 1} y={y + 4} width={CW - 2} height={h - 8} rx={3} fill={v ? ratingColor(v) : '#24201B'} />));
    if (r.type === 'line') {
      const top = y + 10, bot = y + h - 6, yy = (v: number) => bot - ((v - r.min) / (r.max - r.min)) * (bot - top), c = accentColor(r.accent);
      const pts = r.values.map((v, i) => [cx(i), yy(v)] as [number, number]);
      if (r.range) { const a = yy(Math.min(r.range[1], r.max)), b = yy(Math.max(r.range[0], r.min));
        g.push(<rect key="rg" x={LAB} y={a} width={width - LAB} height={b - a} fill={`url(#${hatch})`} />);
        r.rangeLabel && g.push(<text key="rgl" x={width - 2} y={a - 3} fontSize={8.5} fill={colors.text3} textAnchor="end">{r.rangeLabel}</text>); }
      if (r.band) g.push(<path key="bd" d={bandPath(r.band.map((v, i) => [cx(i), yy(v)] as [number, number]), pts)} fill={c} fillOpacity={0.25} />);
      if (r.companion) g.push(<path key="cp" d={linePath(r.companion.map((v, i) => [cx(i), yy(v)] as [number, number]))} stroke={c} strokeWidth={1.6} strokeDasharray="2 3" fill="none" />);
      g.push(<path key="ln" d={linePath(pts)} stroke={c} strokeWidth={2} fill="none" strokeLinejoin="round" strokeLinecap="round" />);
      (r.labelAt ?? []).forEach(i => g.push(<g key={'la' + i}><circle cx={cx(i)} cy={yy(r.values[i])} r={3} fill={c} stroke={colors.surface} strokeWidth={1.5} />
        <text x={cx(i)} y={yy(r.values[i]) - 6} fontSize={10} fill={colors.text} textAnchor="middle" fontWeight={600}>{r.values[i]}</text></g>));
    }
    if (r.type === 'bars') { const top = y + (r.labelEvery ? 13 : 5), bot = y + h - 4, c = accentColor(r.accent);
      r.values.forEach((v, i) => { if (!v) return; const bh = Math.max(2, (v / r.max) * (bot - top)); const hi = !r.highlight || r.highlight.includes(i);
        g.push(<rect key={i} x={cx(i) - CW * 0.32} y={bot - bh} width={CW * 0.64} height={bh} rx={2.5} fill={c} fillOpacity={hi ? 1 : 0.5} />);
        if (r.labelEvery && i % r.labelEvery === 0) g.push(<text key={'t' + i} x={cx(i)} y={bot - bh - 3} fontSize={8.5} fill={colors.text2} textAnchor="middle">{v.toFixed(r.decimals ?? 0)}</text>); }); }
    if (r.type === 'arrows') r.directions.forEach((d, i) => { if (r.every && i % r.every) return; const t = r.shore?.[i];
      g.push(<g key={i}><g transform={`translate(${cx(i)} ${y + (r.shore ? 11 : h / 2)}) rotate(${d + 180})`}><path d="M0 -6 L0 6 M-3 2.5 L0 6 L3 2.5" stroke={accentColor(r.accent)} strokeWidth={1.7} fill="none" strokeLinecap="round" strokeLinejoin="round" /></g>
        {t && <text x={cx(i)} y={y + h - 4} fontSize={7.5} textAnchor="middle" fill={t === 'off' ? colors.warnRed : t === 'side' || t === 'side-on' ? colors.text : colors.text2} fontWeight={t === 'off' ? 700 : 400}>{t === 'side-on' ? 'S-on' : t}</text>}</g>); });
    if (r.type === 'numbers') r.values.forEach((v, i) => { if (r.every && i % r.every) return;
      const col = r.emphasizeAbove !== undefined && v > r.emphasizeAbove ? colors.heat : r.accent ? accentColor(r.accent) : colors.text2;
      g.push(<text key={i} x={cx(i)} y={y + h / 2 + 4} fontSize={10} fill={col} textAnchor="middle">{v}{r.suffix ?? ''}</text>); });
    if (r.type === 'category') { r.values.forEach((v, i) => { const s = r.styles[v]; s && g.push(<rect key={i} x={LAB + i * CW + 1} y={y + 5} width={CW - 2} height={h - 10} rx={3} fill={s.color} fillOpacity={s.opacity ?? 1} />); });
      r.values.forEach((v, i) => { const s = r.styles[v]; if (!s?.text || (i && r.values[i - 1] === v)) return; let run = 1; while (r.values[i + run] === v) run++;
        run >= 2 && g.push(<text key={'t' + i} x={LAB + i * CW + 4} y={y + h / 2 + 3.5} fontSize={8.5} fill={s.textColor ?? colors.bg} fontWeight={600}>{s.text}</text>); }); }
    out.push(<g key={'r' + k}>{g}</g>);
  });

  return (
    <svg width={width} height={total} role="img" aria-label="hour by hour chart">
      <defs><pattern id={hatch} width={5} height={5} patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width={2} height={5} fill="#3A342C" /></pattern></defs>
      <rect x={LAB} y={14} width={Math.max(0, hx(sunrise) - LAB)} height={total - 14} fill={colors.night} />
      <rect x={hx(sunset)} y={14} width={Math.max(0, width - hx(sunset))} height={total - 14} fill={colors.night} />
      {hours.map((h, i) => h % 2 === 0 && <text key={h} x={cx(i)} y={10} fontSize={9.5} fill={colors.text3} textAnchor="middle">{String(h).padStart(2, '0')}</text>)}
      {best && <rect x={hx(best[0])} y={13} width={hx(best[1]) - hx(best[0])} height={total - 13} rx={6} fill="none" stroke={colors.text} strokeOpacity={0.55} strokeDasharray="2 3" />}
      {out}
    </svg>
  );
}
