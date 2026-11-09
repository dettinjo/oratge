import { WeatherIcon, type WeatherKind } from './WeatherIcon';
import { RatingDots } from './RatingDots';
import { ratingColor, colors } from '../tokens';

export type Sport = 'wing' | 'surf' | 'bike' | 'run' | 'hike';
const sportIcon: Record<Sport, WeatherKind> = { wing: 'wind', surf: 'wave', bike: 'sun', run: 'uv', hike: 'storm' };
const sportName: Record<Sport, string> = { wing: 'Wing', surf: 'Surf', bike: 'Bike', run: 'Run', hike: 'Hike' };

export interface ActivityRowProps {
  sport: Sport;
  /** Today's rating 0–5. */
  rating: number;
  /** Best window, e.g. "13–17 h", "all day", or "—". */
  window: string;
  /** Short reason, e.g. "side-on SW 16–19 kn". */
  reason: string;
  /** Overrides the leading glyph (defaults to the sport's main driver: wind, waves, sun, UV, storm). */
  icon?: WeatherKind;
}

/** One row of the Today screen's "Today for you" list. Stack 3–5 in a column; rows draw their own dividers. */
export function ActivityRow({ sport, rating, window, reason, icon }: ActivityRowProps) {
  return (
    <div className="og-act">
      <WeatherIcon kind={icon ?? sportIcon[sport]} size={18} />
      <div className="og-grow"><div className="og-act-name">{sportName[sport]}</div><div className="og-act-why">{reason}</div></div>
      <RatingDots value={rating} />
      <span className="og-act-window" style={{ color: rating >= 3 ? ratingColor(rating) : colors.text3 }}>{window}</span>
    </div>
  );
}
