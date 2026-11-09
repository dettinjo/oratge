import { colors, ratingRamp } from '../tokens';

export interface CalendarHeatmapProps {
  /** weeks[w][d] = level 0–5 (0 = none) for each day, Monday first. */
  weeks: number[][];
  /** Labels spaced along the bottom, e.g. ["May", "Jun", …]. */
  months?: string[];
  /** Legend end labels, e.g. ["0 h", "6+ h"]. */
  legend?: [string, string];
  cell?: number;
}

/** History heatmap (e.g. rideable hours per day) on the sage rating ramp. */
export function CalendarHeatmap({ weeks, months = [], legend, cell = 12.4 }: CalendarHeatmapProps) {
  const w = 14 + weeks.length * cell;
  return (
    <svg width={Math.max(w, 230)} height={legend ? 128 : 112} role="img" aria-label="calendar heatmap">
      {['M', '', 'W', '', 'F', '', 'S'].map((d, i) => <text key={i} x={0} y={i * (cell + 2) + 10} fontSize={9} fill={colors.text3}>{d}</text>)}
      {weeks.map((wk, x) => wk.map((v, d) => <rect key={x + '-' + d} x={14 + x * cell} y={d * (cell + 2)} width={cell - 2} height={cell} rx={2.5} fill={v ? ratingRamp[v - 1] : '#24201B'} />))}
      {months.map((m, i) => <text key={m} x={14 + (i * weeks.length * cell) / months.length} y={112} fontSize={9.5} fill={colors.text3}>{m}</text>)}
      {legend && <g transform={`translate(${Math.max(w, 230) - 136} 118)`}><text x={0} y={8} fontSize={9} fill={colors.text3}>{legend[0]}</text>
        {ratingRamp.map((c, i) => <rect key={c} x={24 + i * 13} y={0} width={11} height={9} rx={2} fill={c} />)}<text x={92} y={8} fontSize={9} fill={colors.text3}>{legend[1]}</text></g>}
    </svg>
  );
}
