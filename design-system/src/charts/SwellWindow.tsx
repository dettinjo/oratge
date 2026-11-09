import { colors } from '../tokens';
import { polar } from '../svg';

export interface SwellWindowProps {
  /** Swell direction FROM, degrees. */
  swellFrom: number;
  /** Directions the beach is open to, [from, to] clockwise in degrees, e.g. [40, 180]. */
  exposure: [number, number];
  size?: number;
}

/** Surf compass: the sea-facing window shaded sea blue, the swell arrow travelling towards the beach. Shows at a glance whether the swell can reach the spot. */
export function SwellWindow({ swellFrom, exposure, size = 140 }: SwellWindowProps) {
  const c = size / 2, r = c - 12, [a0, a1] = exposure;
  const [x0, y0] = polar(c, c, r, a0), [x1, y1] = polar(c, c, r, a1);
  const mid = a0 + (((a1 - a0 + 360) % 360) / 2), [sx1, sy1] = polar(c, c, r + 2, mid - 90), [sx2, sy2] = polar(c, c, r + 2, mid + 90);
  const [ax, ay] = polar(c, c, r - 4, swellFrom), [bx, by] = polar(c, c, 8, swellFrom);
  const ang = Math.atan2(by - ay, bx - ax), hx = (d: number) => bx - 9 * Math.cos(ang + d), hy = (d: number) => by - 9 * Math.sin(ang + d);
  return (
    <svg width={size} height={size} role="img" aria-label={`swell from ${swellFrom} degrees`}>
      <path d={`M${c} ${c} L${x0} ${y0} A${r} ${r} 0 ${((a1 - a0 + 360) % 360) > 180 ? 1 : 0} 1 ${x1} ${y1} Z`} fill={colors.water} fillOpacity={0.16} />
      <circle cx={c} cy={c} r={r} fill="none" stroke={colors.line} />
      {([['N', 0], ['E', 90], ['S', 180], ['W', 270]] as const).map(([t, a]) => { const [x, y] = polar(c, c, r - 11, a); return <text key={t} x={x} y={y + 3.5} fontSize={9.5} fill={colors.text3} textAnchor="middle">{t}</text>; })}
      <line x1={sx1} y1={sy1} x2={sx2} y2={sy2} stroke={colors.sand} strokeDasharray="3 3" />
      <path d={`M${ax} ${ay} L${bx} ${by} M${hx(0.5)} ${hy(0.5)} L${bx} ${by} L${hx(-0.5)} ${hy(-0.5)}`} stroke={colors.water} strokeWidth={2.6} fill="none" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx={c} cy={c} r={3} fill={colors.sand} />
    </svg>
  );
}
