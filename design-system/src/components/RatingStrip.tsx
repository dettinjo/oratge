import { ratingColor } from '../tokens';

export interface RatingStripProps {
  /** One rating (0–5) per slot, usually per hour. */
  values: number[];
  /** Optional text under the strip, left / centre / right (e.g. ["08 h", "today", "22 h"]). */
  caption?: [string, string, string];
  height?: number;
}

/** Compact horizontal bar of rating cells — "how good is each hour". Used on spot cards and the go-window. */
export function RatingStrip({ values, caption, height = 8 }: RatingStripProps) {
  return (
    <div>
      <div style={{ display: 'flex', gap: 3 }}>{values.map((v, i) => <i key={i} style={{ flex: 1, height, borderRadius: 2, background: v ? ratingColor(v) : '#2A261F', display: 'block' }} />)}</div>
      {caption && <div className="og-faint" style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10.5, marginTop: 4 }}><span>{caption[0]}</span><span>{caption[1]}</span><span>{caption[2]}</span></div>}
    </div>
  );
}
