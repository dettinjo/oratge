import * as React from 'react';

/**
 * SwellWindow — from @oratge/ui@0.1.0.
 */
export interface SwellWindowProps {
  /** Swell direction FROM, degrees. */
  swellFrom: number;
  /** Directions the beach is open to, [from, to] clockwise in degrees, e.g. [40, 180]. */
  exposure: [number, number];
  size?: number;
}

export declare const SwellWindow: React.ComponentType<SwellWindowProps>;
