import * as React from 'react';

/**
 * MonthBars — from @oratge/ui@0.1.0.
 */
export interface MonthBarsProps {
  /** 12 monthly values, January first. */
  values: number[];
  accent?: "sun" | "storm" | "wind" | "heat" | "snow" | "water" | "neutral";
  /** Index of the month to emphasise and label (e.g. the best month). */
  highlight?: number;
  /** Index of the current month (bold axis letter). */
  current?: number;
  width?: number;
}

export declare const MonthBars: React.ComponentType<MonthBarsProps>;
