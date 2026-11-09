import { WeatherIcon, type WeatherKind } from './WeatherIcon';
import { colors } from '../tokens';

export interface ForecastDayRowProps {
  day: string;
  sky: WeatherKind;
  /** Rain probability %; hidden when 0. */
  rainChance: number;
  min: number;
  max: number;
  /** Week-wide min/max so every row's bar shares one scale. */
  scale: [number, number];
}

/** One line of the 7-day list: day, sky, rain chance, min—max on a shared temperature scale. */
export function ForecastDayRow({ day, sky, rainChance, min, max, scale }: ForecastDayRowProps) {
  const [lo, hi] = scale, w = 120;
  return (
    <div className="og-day">
      <span style={{ width: 52 }}>{day}</span><WeatherIcon kind={sky} size={20} />
      <span style={{ width: 40, textAlign: 'right', fontSize: 12, color: rainChance ? colors.water : 'transparent' }}>{rainChance}%</span>
      <span className="og-grow" />
      <span className="og-muted" style={{ width: 28, textAlign: 'right' }}>{min}°</span>
      <span style={{ width: w, height: 4, borderRadius: 2, background: '#2A261F', position: 'relative', margin: '0 10px' }}>
        <i style={{ position: 'absolute', left: ((min - lo) / (hi - lo)) * w, width: ((max - min) / (hi - lo)) * w, height: 4, borderRadius: 2, background: `linear-gradient(90deg, ${colors.sun}, ${colors.heat})` }} />
      </span>
      <span style={{ width: 26 }}>{max}°</span>
    </div>
  );
}
