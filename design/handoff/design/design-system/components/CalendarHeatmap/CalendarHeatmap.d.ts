import * as React from 'react';

/**
 * CalendarHeatmap — from @oratge/ui@0.1.0.
 */
export interface CalendarHeatmapProps {
  /** weeks[w][d] = level 0–5 (0 = none) for each day, Monday first. */
  weeks: number[][];
  /** Labels spaced along the bottom, e.g. ["May", "Jun", …]. */
  months?: string[];
  /** Legend end labels, e.g. ["0 h", "6+ h"]. */
  legend?: [string, string];
  cell?: number;
}

export declare const CalendarHeatmap: React.ComponentType<CalendarHeatmapProps>;
