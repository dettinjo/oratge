import { colors } from '../tokens';
import { linePath } from '../svg';

export interface AltitudePoint { altitude: number; temp: number; label?: string }

export interface AltitudeProfileProps {
  /** Points from valley to summit. */
  points: AltitudePoint[];
  /** Snow level in m (frost line). */
  snowLevel?: number;
  width?: number;
}

/** Hike chart: temperature by altitude (valley → hut → summit) with the 0 °C line and snow level. */
export function AltitudeProfile({ points, snowLevel, width = 322 }: AltitudeProfileProps) {
  const alts = points.map(p => p.altitude), temps = points.map(p => p.temp);
  const aLo = Math.floor(Math.min(...alts) / 500) * 500, aHi = Math.ceil(Math.max(...alts) / 500) * 500;
  const tLo = Math.min(-4, ...temps) - 1, tHi = Math.max(...temps) + 5;
  const x = (t: number) => 40 + ((t - tLo) / (tHi - tLo)) * (width - 52), y = (a: number) => 136 - ((a - aLo) / (aHi - aLo)) * 124;
  const ticks: number[] = []; for (let a = aLo + 500; a <= aHi; a += 500) ticks.push(a);
  return (
    <svg width={width} height={150} role="img" aria-label="temperature by altitude" style={{ overflow: 'visible' }}>
      {ticks.map(a => <g key={a}><line x1={34} x2={width} y1={y(a)} y2={y(a)} stroke={colors.line} strokeWidth={0.5} /><text x={0} y={y(a) + 3} fontSize={9} fill={colors.text3}>{a} m</text></g>)}
      <line x1={x(0)} x2={x(0)} y1={6} y2={140} stroke={colors.snow} strokeDasharray="2 3" /><text x={x(0) + 4} y={140} fontSize={9} fill={colors.snow}>0 °C</text>
      {snowLevel && <><line x1={34} x2={width} y1={y(snowLevel)} y2={y(snowLevel)} stroke={colors.snow} strokeOpacity={0.6} />
        <text x={width} y={y(snowLevel) - 4} fontSize={9} fill={colors.snow} textAnchor="end">snow level {snowLevel} m</text></>}
      <path d={linePath(points.map(p => [x(p.temp), y(p.altitude)] as [number, number]))} stroke={colors.heat} strokeWidth={2} fill="none" />
      {points.map((p, i) => <g key={i}><circle cx={x(p.temp)} cy={y(p.altitude)} r={3.5} fill={colors.heat} stroke={colors.surface} strokeWidth={1.5} />
        {p.label && <text x={x(p.temp) + (p.temp < 0 ? -8 : 8)} textAnchor={p.temp < 0 ? 'end' : 'start'} y={y(p.altitude) + 4} fontSize={10} fill={colors.text}>{p.label} {p.temp}°</text>}</g>)}
    </svg>
  );
}
