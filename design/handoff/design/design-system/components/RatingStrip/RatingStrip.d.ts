import * as React from 'react';

/**
 * RatingStrip — from @oratge/ui@0.1.0.
 */
export interface RatingStripProps {
  /** One rating (0–5) per slot, usually per hour. */
  values: number[];
  /** Optional text under the strip, left / centre / right (e.g. ["08 h", "today", "22 h"]). */
  caption?: [string, string, string];
  height?: number;
}

export declare const RatingStrip: React.ComponentType<RatingStripProps>;
