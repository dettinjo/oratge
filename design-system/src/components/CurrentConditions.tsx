import { WeatherIcon, type WeatherKind } from './WeatherIcon';
import { colors } from '../tokens';

export interface CurrentConditionsProps {
  place: string;
  /** Source line, e.g. "Meteocat · Zoo station · 8 min ago". */
  source: string;
  sky: WeatherKind;
  /** Current temperature °C. */
  temp: number;
  /** e.g. "Mostly sunny". */
  summary: string;
  feels: number;
  min: number;
  max: number;
  /** e.g. "SW 14 kn · gusts 21". */
  wind: string;
}

/** Today-screen hero: place, source and age, big temperature, sky, feels-like, range and wind. */
export function CurrentConditions({ place, source, sky, temp, summary, feels, min, max, wind }: CurrentConditionsProps) {
  return (
    <div>
      <div style={{ fontSize: 17, fontWeight: 600 }}>{place}</div>
      <div className="og-faint" style={{ fontSize: 11, marginTop: 2 }}>{source}</div>
      <div className="og-row" style={{ marginTop: 18, gap: 14 }}>
        <WeatherIcon kind={sky} size={62} />
        <div className="og-hero-temp">{temp}°</div>
        <div style={{ marginLeft: 6 }}>
          <div style={{ fontSize: 15, fontWeight: 500 }}>{summary}</div>
          <div className="og-muted" style={{ fontSize: 12.5, marginTop: 4 }}>Feels {feels}° · ↓{min}° ↑{max}°</div>
          <div className="og-muted" style={{ fontSize: 12.5, marginTop: 2 }}><span style={{ color: colors.wind }}>➚</span> {wind}</div>
        </div>
      </div>
    </div>
  );
}
