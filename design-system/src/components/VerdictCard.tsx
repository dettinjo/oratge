import { RatingDots } from './RatingDots';

export interface VerdictCardProps {
  /** Day rating 0–5 for the chosen sport. */
  rating: number;
  /** Headline plan, e.g. "Best 13–17 h · peak 14–16 h" or "Leave 09:00 → back 12:00". */
  best: string;
  /** One or two sentences explaining why. */
  summary: string;
  /** e.g. "High confidence" — how much the forecasts agree. */
  confidence?: string;
}

/** Top-of-planner verdict: rating, the best window and the reasoning. One per daily planner. */
export function VerdictCard({ rating, best, summary, confidence }: VerdictCardProps) {
  return (
    <div className="og-card">
      <div className="og-row"><RatingDots value={rating} size="lg" showWord /><div className="og-grow" />{confidence && <span className="og-pill">{confidence}</span>}</div>
      <div className="og-verdict-best">{best}</div>
      <div className="og-verdict-summary">{summary}</div>
    </div>
  );
}
