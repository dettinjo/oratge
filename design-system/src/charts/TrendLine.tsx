import { colors, accentColor, type Accent } from '../tokens';
import { linePath, bandPath } from '../svg';

export interface TrendLineProps {
  /** Main series (solid). */
  values: number[];
  accent: Accent;
  /** Optional upper band in the same unit (e.g. gusts). */
  band?: number[];
  /** Optional comparison series, dashed neutral (e.g. the forecast vs measured). */
  compare?: number[];
  /** Mark this index with a dot and `nowLabel`. */
  nowIndex?: number;
  nowLabel?: string;
  /** Left/right caption under the chart, e.g. ["−12 h", "+12 h"]. */
  caption?: [string, string];
  /** Start/end value labels. */
  endLabels?: [string, string];
  min?: number;
  max?: number;
  width?: number;
  height?: number;
}

/** Small single-measure trend: live wind sparkline, pressure trend, forecast-vs-measured, buoy history. One axis only — never mix units. */
export function TrendLine({ values, accent, band, compare, nowIndex, nowLabel, caption, endLabels, min, max, width = 322, height = 70 }: TrendLineProps) {
  const all = [...values, ...(band ?? []), ...(compare ?? [])];
  const lo = min ?? Math.min(...all), hi = max ?? Math.max(...all), n = Math.max(values.length, compare?.length ?? 0);
  const top = endLabels || nowLabel ? 16 : 4, bot = height - (caption ? 14 : 4);
  const x = (i: number) => 4 + (i * (width - 8)) / (n - 1), y = (v: number) => bot - ((v - lo) / (hi - lo || 1)) * (bot - top);
  const c = accent === 'neutral' ? colors.text2 : accentColor(accent);
  const pts = values.map((v, i) => [x(i), y(v)] as [number, number]);
  return (
    <svg width={width} height={height} role="img" aria-label="trend">
      {band && <path d={bandPath(band.map((v, i) => [x(i), y(v)] as [number, number]), pts)} fill={c} fillOpacity={0.25} />}
      {compare && <path d={linePath(compare.map((v, i) => [x(i), y(v)] as [number, number]))} stroke={colors.text2} strokeWidth={1.6} strokeDasharray="3 3" fill="none" />}
      <path d={linePath(pts)} stroke={c} strokeWidth={2} fill="none" strokeLinejoin="round" />
      {nowIndex !== undefined && <><circle cx={x(nowIndex)} cy={y(values[nowIndex])} r={3.5} fill={c} stroke={colors.surface} strokeWidth={2} />
        {nowLabel && <text x={x(nowIndex)} y={y(values[nowIndex]) - 7} fontSize={10} fill={colors.text} textAnchor={nowIndex >= n - 2 ? 'end' : nowIndex <= 1 ? 'start' : 'middle'} fontWeight={600}>{nowLabel}</text>}</>}
      {endLabels && <><text x={x(0)} y={y(values[0]) - 6} fontSize={10} fill={colors.text}>{endLabels[0]}</text>
        <text x={x(values.length - 1)} y={y(values[values.length - 1]) - 6} fontSize={10} fill={colors.text} textAnchor="end">{endLabels[1]}</text></>}
      {caption && <><text x={0} y={height - 2} fontSize={9} fill={colors.text3}>{caption[0]}</text><text x={width} y={height - 2} fontSize={9} fill={colors.text3} textAnchor="end">{caption[1]}</text></>}
    </svg>
  );
}
