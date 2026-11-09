import { colors } from '../tokens';
import { polar } from '../svg';

export interface WindCompassProps {
  /** Direction the wind comes FROM, degrees. */
  from: number;
  /** Mean speed (kn), shown in the centre. */
  speed: number;
  /** Direction the beach faces (towards the sea), degrees. Sectors: from the sea = rideable, from land = offshore. */
  shoreFacing: number;
  /** Caption under the dial, e.g. "live · side-shore". */
  caption?: string;
  size?: number;
}

/** Live wind against the shoreline: offshore half shaded neutral, sea-side half tinted sage-teal, dashed shoreline, arrow pointing downwind. */
export function WindCompass({ from, speed, shoreFacing, caption, size = 130 }: WindCompassProps) {
  const c = size / 2, r = c - 13;
  const arc = (a0: number, a1: number, fill: string, op: number) => { const [x0, y0] = polar(c, c, r, a0), [x1, y1] = polar(c, c, r, a1);
    return <path d={`M${c} ${c} L${x0} ${y0} A${r} ${r} 0 ${((a1 - a0 + 360) % 360) > 180 ? 1 : 0} 1 ${x1} ${y1} Z`} fill={fill} fillOpacity={op} />; };
  const [s1x, s1y] = polar(c, c, r + 4, shoreFacing - 90), [s2x, s2y] = polar(c, c, r + 4, shoreFacing + 90);
  return (
    <svg width={size} height={size + (caption ? 12 : 0)} role="img" aria-label={`wind from ${from} degrees, ${speed} knots`}>
      {arc(shoreFacing + 90, shoreFacing + 270, colors.text, 0.04)}
      {arc(shoreFacing - 90, shoreFacing + 90, colors.wind, 0.1)}
      <circle cx={c} cy={c} r={r} fill="none" stroke={colors.line} />
      {Array.from({ length: 12 }, (_, k) => { const [a, b] = polar(c, c, r - 4, k * 30), [e, f] = polar(c, c, r, k * 30); return <line key={k} x1={a} y1={b} x2={e} y2={f} stroke={colors.text3} />; })}
      {([['N', 0], ['E', 90], ['S', 180], ['W', 270]] as const).map(([t, a]) => { const [x, y] = polar(c, c, r - 13, a); return <text key={t} x={x} y={y + 3.5} fontSize={9.5} fill={colors.text3} textAnchor="middle">{t}</text>; })}
      <line x1={s1x} y1={s1y} x2={s2x} y2={s2y} stroke={colors.sand} strokeWidth={1.2} strokeDasharray="3 3" />
      <g transform={`rotate(${from + 180} ${c} ${c})`}><path d={`M${c} ${c + 30} L${c} ${c - 26} M${c - 6} ${c - 18} L${c} ${c - 27} L${c + 6} ${c - 18}`} stroke={colors.wind} strokeWidth={2.6} fill="none" strokeLinecap="round" strokeLinejoin="round" /></g>
      <circle cx={c} cy={c} r={15} fill={colors.surface} />
      <text x={c} y={c + 5} fontSize={14} fontWeight={700} fill={colors.text} textAnchor="middle">{speed}</text>
      {caption && <text x={4} y={size + 9} fontSize={9} fill={colors.text3}>{caption}</text>}
    </svg>
  );
}
