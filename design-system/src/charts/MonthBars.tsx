import { colors, accentColor, type Accent } from '../tokens';

export interface MonthBarsProps {
  /** 12 monthly values, January first. */
  values: number[];
  accent?: Accent;
  /** Index of the month to emphasise and label (e.g. the best month). */
  highlight?: number;
  /** Index of the current month (bold axis letter). */
  current?: number;
  width?: number;
}

/** Climatology bars per month, e.g. rideable days per month at a station. */
export function MonthBars({ values, accent = 'wind', highlight, current, width = 350 }: MonthBarsProps) {
  const bot = 124, top = 10, bw = (width - 22) / 12, max = Math.max(...values) * 1.12, y = (k: number) => bot - (k / max) * (bot - top), c = accentColor(accent);
  const grid = [max / 2.4, max / 1.2].map(v => Math.round(v));
  return (
    <svg width={width} height={150} role="img" aria-label="monthly values">
      {grid.map(k => <g key={k}><line x1={0} x2={width - 22} y1={y(k)} y2={y(k)} stroke={colors.line} strokeWidth={0.6} /><text x={width} y={y(k) + 3.5} fontSize={9.5} fill={colors.text3} textAnchor="end">{k}</text></g>)}
      {values.map((k, i) => <g key={i}><rect x={i * bw + 3} y={y(k)} width={bw - 6} height={bot - y(k)} rx={3} fill={c} fillOpacity={i === highlight ? 1 : 0.5} />
        <text x={i * bw + bw / 2} y={bot + 14} fontSize={9.5} fill={i === current ? colors.text : colors.text3} textAnchor="middle" fontWeight={i === current ? 700 : 400}>{'JFMAMJJASOND'[i]}</text></g>)}
      {highlight !== undefined && <text x={highlight * bw + bw / 2} y={y(values[highlight]) - 5} fontSize={10} fill={colors.text} textAnchor="middle" fontWeight={600}>{values[highlight]}</text>}
      <line x1={0} x2={width - 22} y1={bot} y2={bot} stroke={colors.line} />
    </svg>
  );
}
