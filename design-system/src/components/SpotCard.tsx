import { RatingStrip } from './RatingStrip';
import { ratingColor, colors } from '../tokens';

export interface SpotCardProps {
  name: string;
  /** e.g. "Wing · flatwater" or "Hike · 1706 m". */
  kind: string;
  /** Live wind in kn at the linked station. */
  wind: number;
  gust: number;
  /** Direction the wind comes FROM, degrees. */
  windFrom: number;
  /** Today's hourly ratings (e.g. 08–22 h in 2 h steps). */
  today: number[];
  /** Best window text, e.g. "13–17 h". */
  window: string;
  /** Best rating today, colours the window. */
  rating: number;
}

/** Saved place with live wind and today's rating strip. Stack in a column on the Spots screen. */
export function SpotCard({ name, kind, wind, gust, windFrom, today, window, rating }: SpotCardProps) {
  return (
    <div className="og-card" style={{ padding: '13px 14px' }}>
      <div className="og-row">
        <div><div style={{ fontSize: 15, fontWeight: 600 }}>{name}</div><div className="og-faint" style={{ fontSize: 11.5, marginTop: 2 }}>{kind}</div></div>
        <div className="og-grow" />
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 17, fontWeight: 600 }}><span style={{ color: colors.wind, display: 'inline-block', transform: `rotate(${windFrom + 90}deg)`, fontSize: 14 }}>➜</span> {wind}<span className="og-faint" style={{ fontSize: 11 }}> kn</span></div>
          <div className="og-faint" style={{ fontSize: 11 }}>gusts {gust}</div>
        </div>
      </div>
      <div className="og-row" style={{ marginTop: 10, gap: 10 }}>
        <div className="og-grow"><RatingStrip values={today} /></div>
        <span style={{ fontSize: 12, fontWeight: 600, color: rating >= 3 ? ratingColor(rating) : colors.text2 }}>{window}</span>
      </div>
    </div>
  );
}
