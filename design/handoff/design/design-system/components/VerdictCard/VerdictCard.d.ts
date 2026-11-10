import * as React from 'react';

/**
 * VerdictCard — from @oratge/ui@0.1.0.
 */
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

export declare const VerdictCard: React.ComponentType<VerdictCardProps>;
