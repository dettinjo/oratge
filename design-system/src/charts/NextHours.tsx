import { colors } from '../tokens';
import { linePath } from '../svg';
import { WeatherIcon, type WeatherKind } from '../components/WeatherIcon';

export interface NextHoursProps {
  /** Hourly temperature (°C), usually 24 values. */
  temps: number[];
  /** Hourly rain probability (%), same length. Drawn as a separate strip — never on the temperature axis. */
  rain: number[];
  /** Hourly sky, same length (icons every 3 h). */
  sky: WeatherKind[];
  /** Hour of the first value, e.g. 10. */
  startHour: number;
  width?: number;
}

/** Today's next-24-h strip: sky icons, apricot temperature line with min/max labels, blue rain-probability bars underneath. */
export function NextHours({ temps, rain, sky, startHour, width = 350 }: NextHoursProps) {
  const n = temps.length, lo = Math.min(...temps), hi = Math.max(...temps);
  const x = (i: number) => 8 + (i * (width - 16)) / (n - 1), y = (t: number) => 66 - ((t - lo) / (hi - lo || 1)) * 30;
  const iMax = temps.indexOf(hi), iMin = temps.lastIndexOf(lo), peak = rain.indexOf(Math.max(...rain));
  return (
    <svg width={width} height={120} role="img" aria-label="next 24 hours">
      {sky.map((k, i) => i % 3 === 0 && <g key={i} transform={`translate(${x(i) - 8} 0) scale(.6667)`}><WeatherIcon kind={k} size={24} /></g>)}
      <path d={linePath(temps.map((t, i) => [x(i), y(t)] as [number, number]))} stroke={colors.heat} strokeWidth={2} fill="none" strokeLinejoin="round" strokeLinecap="round" />
      {[[0, -7], [iMax, -7], [iMin, 14]].map(([i, dy]) => <g key={i}><circle cx={x(i)} cy={y(temps[i])} r={3.5} fill={colors.heat} stroke={colors.bg} strokeWidth={2} />
        <text x={x(i)} y={y(temps[i]) + dy} fontSize={11} fill={colors.text} textAnchor={i === iMin && i > n - 3 ? 'end' : 'middle'} fontWeight={600}>{temps[i]}°</text></g>)}
      <line x1={0} x2={width} y1={100} y2={100} stroke={colors.line} />
      {rain.map((p, i) => p > 0 && <rect key={i} x={x(i) - 4.5} y={100 - (p / 100) * 26} width={9} height={(p / 100) * 26} rx={2} fill={colors.water} />)}
      {rain[peak] > 0 && <text x={x(peak) + 8} y={86} fontSize={10.5} fill={colors.text2}>{rain[peak]}% rain {String((startHour + peak) % 24).padStart(2, '0')} h</text>}
      {[0, 6, 12, 18].filter(i => i < n).map(i => <text key={i} x={x(i)} y={116} fontSize={10} fill={colors.text3} textAnchor="middle">{String((startHour + i) % 24).padStart(2, '0')} h</text>)}
    </svg>
  );
}
