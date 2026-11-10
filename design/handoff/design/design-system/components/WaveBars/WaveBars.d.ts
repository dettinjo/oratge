import * as React from 'react';

/**
 * WaveBars — from @oratge/ui@0.1.0.
 */
export interface WaveBarsProps {
  /** Significant wave height (m) per slot, e.g. every 3 h. */
  heights: number[];
  /** Wave period (s) per slot, printed above bars. */
  periods: number[];
  /** Wind direction FROM per slot (degrees) — sage-teal arrows below the bars. */
  windFrom?: number[];
  /** Day labels; slots are split evenly between them. */
  days?: string[];
  /** Slot indexes to emphasise as the best session. */
  best?: number[];
  /** Axis max in m (default 1.6). */
  max?: number;
  width?: number;
}

export declare const WaveBars: React.ComponentType<WaveBarsProps>;
