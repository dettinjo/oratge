import { colors } from '../tokens';

export interface WaveBarsProps {
  /** Significant wave height (m) per slot, e.g. every 3 h. */
  heights: number[];
  /** Wave period (s) per slot, printed above bars. */
  periods: number[];
  /** Wind direction FROM per slot (degrees) — sage-teal arrows below the bars. */
  windFrom?: number[];
  /** Day labels; slots are split evenly between them. */
  days?: string[];
  /** Slot indexes to emphasise as the best session. */
  best?: number[];
  /** Axis max in m (default 1.6). */
  max?: number;
  width?: number;
}

/** Surf chart: sea-blue wave-height bars with the period on top and wind arrows underneath. */
export function WaveBars({ heights, periods, windFrom, days = [], best = [], max = 1.6, width = 322 }: WaveBarsProps) {
  const top = 28, bot = 150, n = heights.length, bw = (width - 30) / n;
  const x = (i: number) => 4 + i * bw, y = (v: number) => bot - (v / max) * (bot - top), per = days.length ? n / days.length : n;
  return (
    <svg width={width} height={214} role="img" aria-label="wave height and period">
      <text x={0} y={12} fontSize={10} fill={colors.text3}>m</text>
      {[0.5, 1, 1.5].filter(k => k <= max).map(k => <g key={k}><line x1={0} x2={width - 22} y1={y(k)} y2={y(k)} stroke={colors.line} strokeWidth={0.6} /><text x={width} y={y(k) + 3.5} fontSize={10} fill={colors.text3} textAnchor="end">{k}</text></g>)}
      <line x1={0} x2={width - 22} y1={bot} y2={bot} stroke={colors.line} />
      {heights.map((h, i) => { const hi = best.includes(i);
        return <g key={i}><rect x={x(i) + 1} y={y(h)} width={bw - 2} height={bot - y(h)} rx={3} fill={colors.water} fillOpacity={hi || !best.length ? 1 : 0.55} />
          {i % 2 === 0 && <text x={x(i) + bw / 2} y={y(h) - 5} fontSize={9.5} fill={hi ? colors.text : colors.text2} textAnchor="middle" fontWeight={hi ? 700 : 400}>{periods[i]}s</text>}
          {windFrom && i % 2 === 1 && <g transform={`translate(${x(i)} ${bot + 16}) rotate(${windFrom[i] + 180})`}><path d="M0 -5 L0 5 M-2.8 2 L0 5 L2.8 2" stroke={colors.wind} strokeWidth={1.5} fill="none" strokeLinecap="round" /></g>}</g>; })}
      {days.map((d, k) => <g key={d + k}><text x={x(k * per + per / 2)} y={bot + 40} fontSize={11} fill={colors.text2} textAnchor="middle" fontWeight={500}>{d}</text>
        {k > 0 && <line x1={x(k * per)} x2={x(k * per)} y1={top - 10} y2={bot + 28} stroke={colors.line} />}</g>)}
    </svg>
  );
}
