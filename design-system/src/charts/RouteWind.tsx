import { colors } from '../tokens';

export interface RouteWindProps {
  /** Route polyline in chart coordinates (0–322 × 0–150). Closed loops repeat the first point at the end. */
  points: [number, number][];
  /** Wind direction FROM, degrees. */
  windFrom: number;
  /** e.g. "NW 7 kn". */
  windLabel: string;
  /** Headline, e.g. "58 % tailwind on the climb". */
  title?: string;
  /** Labels placed at points: [x, y, text]. */
  labels?: [number, number, string][];
  width?: number;
}

/** Bike route coloured by wind effect for the chosen start time: tailwind sage-teal, crosswind neutral, headwind apricot. */
export function RouteWind({ points, windFrom, windLabel, title, labels = [], width = 322 }: RouteWindProps) {
  const segs = points.slice(0, -1).map((a, i) => { const b = points[i + 1];
    const bearing = ((Math.atan2(b[0] - a[0], a[1] - b[1]) * 180) / Math.PI + 360) % 360;
    const rel = Math.cos(((bearing - (windFrom + 180)) * Math.PI) / 180);
    return { a, b, col: rel > 0.35 ? colors.wind : rel < -0.35 ? colors.heat : colors.text3 }; });
  return (
    <svg width={width} height={172} role="img" aria-label="wind along the route">
      {segs.map((s, i) => <line key={i} x1={s.a[0]} y1={s.a[1]} x2={s.b[0]} y2={s.b[1]} stroke={s.col} strokeWidth={5} strokeLinecap="round" />)}
      <circle cx={points[0][0]} cy={points[0][1]} r={5} fill={colors.text} />
      {labels.map(([x, y, t]) => <text key={t} x={x} y={y} fontSize={9.5} fill={colors.text2}>{t}</text>)}
      <g transform={`translate(${width - 22} 22) rotate(${windFrom + 180})`}><path d="M0 -9 L0 9 M-4 4 L0 9 L4 4" stroke={colors.wind} strokeWidth={2} fill="none" strokeLinecap="round" /></g>
      <text x={width - 22} y={46} fontSize={9} fill={colors.text2} textAnchor="middle">{windLabel}</text>
      {title && <text x={0} y={12} fontSize={11} fill={colors.text} fontWeight={600}>{title}</text>}
      {([['tailwind', colors.wind], ['crosswind', colors.text3], ['headwind', colors.heat]] as const).map(([t, c], k) => <g key={t} transform={`translate(${k * 84} 162)`}><rect width={10} height={10} rx={3} fill={c} y={-9} /><text x={16} fontSize={11} fill={colors.text2}>{t}</text></g>)}
    </svg>
  );
}
