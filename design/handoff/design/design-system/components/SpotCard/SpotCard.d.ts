import * as React from 'react';

/**
 * SpotCard — from @oratge/ui@0.1.0.
 */
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

export declare const SpotCard: React.ComponentType<SpotCardProps>;
