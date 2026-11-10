import * as React from 'react';

/**
 * TrendLine — from @oratge/ui@0.1.0.
 */
export interface TrendLineProps {
  /** Main series (solid). */
  values: number[];
  accent: "sun" | "storm" | "wind" | "heat" | "snow" | "water" | "neutral";
  /** Optional upper band in the same unit (e.g. gusts). */
  band?: number[];
  /** Optional comparison series, dashed neutral (e.g. the forecast vs measured). */
  compare?: number[];
  /** Mark this index with a dot and `nowLabel`. */
  nowIndex?: number;
  nowLabel?: string;
  /** Left/right caption under the chart, e.g. ["−12 h", "+12 h"]. */
  caption?: [string, string];
  /** Start/end value labels. */
  endLabels?: [string, string];
  min?: number;
  max?: number;
  width?: number;
  height?: number;
}

export declare const TrendLine: React.ComponentType<TrendLineProps>;
