import { colors } from '../tokens';
import { linePath, bandPath, uid } from '../svg';

export interface WindBandProps {
  /** Mean wind per hour (kn), any length (e.g. 72 for 3 days). */
  mean: number[];
  /** Gusts per hour (kn), same length. */
  gust: number[];
  /** Direction FROM per hour, degrees — arrows drawn every 6 h. */
  directions?: number[];
  /** The rider's usable range, hatched, e.g. [14, 24]. */
  range?: [number, number];
  /** Day labels, one per 24 values. */
  days?: string[];
  /** [startIndex, endIndex) hour ranges to shade as night. */
  night?: [number, number][];
  /** [startIndex, endIndex] to frame as the best window. */
  best?: [number, number];
  /** Axis max in kn (default 35). */
  max?: number;
  width?: number;
  height?: number;
}

/** Multi-day wind chart: sage-teal mean line, translucent gust band, hatched personal range, night shading, best window. Wing foil signature visual. */
export function WindBand({ mean, gust, directions, range, days, night = [], best, max = 35, width = 322, height = 182 }: WindBandProps) {
  const top = 22, bot = height - 32, n = mean.length;
  const x = (i: number) => 4 + (i * (width - 30)) / (n - 1), y = (k: number) => bot - (k / max) * (bot - top);
  const hatch = uid('og-wb');
  const meanPts = mean.map((v, i) => [x(i), y(v)] as [number, number]);
  return (
    <svg width={width} height={height} role="img" aria-label="wind and gusts">
      <defs><pattern id={hatch} width={5} height={5} patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width={2} height={5} fill="#3A342C" /></pattern></defs>
      {night.map(([a, b], k) => <rect key={k} x={x(a)} y={top} width={x(Math.min(b, n - 1)) - x(a)} height={bot - top} fill={colors.night} />)}
      {range && <rect x={x(0)} y={y(range[1])} width={x(n - 1) - x(0)} height={y(range[0]) - y(range[1])} fill={`url(#${hatch})`} />}
      {[0, 10, 20, 30].filter(k => k <= max).map(k => <g key={k}><line x1={x(0)} x2={x(n - 1)} y1={y(k)} y2={y(k)} stroke={colors.line} strokeWidth={k ? 0.6 : 1} />
        <text x={width} y={y(k) + 3.5} fontSize={10} fill={colors.text3} textAnchor="end">{k}</text></g>)}
      <text x={width} y={top - 4} fontSize={9.5} fill={colors.text3} textAnchor="end">kn</text>
      <path d={bandPath(gust.map((v, i) => [x(i), y(v)] as [number, number]), meanPts)} fill={colors.wind} fillOpacity={0.28} />
      <path d={linePath(meanPts)} stroke={colors.wind} strokeWidth={2} fill="none" strokeLinejoin="round" />
      {best && <><rect x={x(best[0])} y={top - 2} width={x(best[1]) - x(best[0])} height={bot - top + 2} rx={4} fill="none" stroke={colors.text} strokeDasharray="2 2" />
        <text x={(x(best[0]) + x(best[1])) / 2} y={bot + 29} fontSize={10} fill={colors.text} textAnchor="middle">best</text></>}
      {directions && directions.map((d, i) => i % 6 === 2 && <g key={i} transform={`translate(${x(i)} 9) rotate(${d + 180})`}><path d="M0 -6 L0 6 M-3.2 2.5 L0 6 L3.2 2.5" stroke={colors.text2} strokeWidth={1.5} fill="none" strokeLinecap="round" strokeLinejoin="round" /></g>)}
      {days && days.map((d, k) => <g key={d + k}><text x={x(Math.min(k * 24 + 12, n - 1))} y={bot + 16} fontSize={11} fill={colors.text2} textAnchor="middle" fontWeight={500}>{d}</text>
        {k > 0 && <line x1={x(k * 24)} x2={x(k * 24)} y1={top} y2={bot + 6} stroke={colors.line} />}</g>)}
    </svg>
  );
}
