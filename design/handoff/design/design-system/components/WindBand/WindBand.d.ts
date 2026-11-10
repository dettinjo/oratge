import * as React from 'react';

/**
 * WindBand — from @oratge/ui@0.1.0.
 */
export interface WindBandProps {
  /** Mean wind per hour (kn), any length (e.g. 72 for 3 days). */
  mean: number[];
  /** Gusts per hour (kn), same length. */
  gust: number[];
  /** Direction FROM per hour, degrees — arrows drawn every 6 h. */
  directions?: number[];
  /** The rider's usable range, hatched, e.g. [14, 24]. */
  range?: [number, number];
  /** Day labels, one per 24 values. */
  days?: string[];
  /** [startIndex, endIndex) hour ranges to shade as night. */
  night?: [number, number][];
  /** [startIndex, endIndex] to frame as the best window. */
  best?: [number, number];
  /** Axis max in kn (default 35). */
  max?: number;
  width?: number;
  height?: number;
}

export declare const WindBand: React.ComponentType<WindBandProps>;
