import * as React from 'react';

/**
 * HourChart — from @oratge/ui@0.1.0.
 */
export interface HourChartProps {
  /** Column hours, e.g. [7, 8, …, 20]. */
  hours: number[];
  rows: HourRow[];
  /** Recommended window [startHour, endHour] — drawn as a dashed frame. */
  best?: [number, number];
  /** Decimal hours; columns outside daylight are shaded. */
  sunrise?: number;
  sunset?: number;
  width?: number;
}

export declare const HourChart: React.ComponentType<HourChartProps>;
