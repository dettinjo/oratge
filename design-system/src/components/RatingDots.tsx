import { colors, ratingColor, ratingWords } from '../tokens';

export interface RatingDotsProps {
  /** Condition rating 0–5 (0 = not possible). */
  value: number;
  size?: 'sm' | 'lg';
  /** Show the word (Poor … Epic) after the dots. */
  showWord?: boolean;
}

/** Five dots on the sage rating ramp. The filled count AND the colour carry the rating, so it never relies on colour alone. */
export function RatingDots({ value, size = 'sm', showWord }: RatingDotsProps) {
  const v = Math.max(0, Math.min(5, Math.round(value)));
  return (
    <span className={'og-dots' + (size === 'lg' ? ' og-lg' : '')} aria-label={`rating ${v} of 5`}>
      {[0, 1, 2, 3, 4].map(i => <i key={i} style={{ background: i < v ? ratingColor(v) : '#2E2A24' }} />)}
      {showWord && v > 0 && <span className="og-dots-word" style={{ color: v >= 3 ? ratingColor(v) : colors.text2 }}>{ratingWords[v - 1]}</span>}
      {showWord && v === 0 && <span className="og-dots-word" style={{ color: colors.text3 }}>Not possible</span>}
    </span>
  );
}
