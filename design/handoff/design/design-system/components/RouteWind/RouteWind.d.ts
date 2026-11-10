import * as React from 'react';

/**
 * RouteWind — from @oratge/ui@0.1.0.
 */
export interface RouteWindProps {
  /** Route polyline in chart coordinates (0–322 × 0–150). Closed loops repeat the first point at the end. */
  points: [number, number][];
  /** Wind direction FROM, degrees. */
  windFrom: number;
  /** e.g. "NW 7 kn". */
  windLabel: string;
  /** Headline, e.g. "58 % tailwind on the climb". */
  title?: string;
  /** Labels placed at points: [x, y, text]. */
  labels?: [number, number, string][];
  width?: number;
}

export declare const RouteWind: React.ComponentType<RouteWindProps>;
