import * as React from 'react';

/**
 * WindCompass — from @oratge/ui@0.1.0.
 */
export interface WindCompassProps {
  /** Direction the wind comes FROM, degrees. */
  from?: number;
  /** Same as `from`; use this where `from` is a reserved attribute (e.g. a Design canvas). */
  direction?: number;
  /** Mean speed (kn), shown in the centre. */
  speed: number;
  /** Direction the beach faces (towards the sea), degrees. Sectors: from the sea = rideable, from land = offshore. */
  shoreFacing: number;
  /** Caption under the dial, e.g. "live · side-shore". */
  caption?: string;
  size?: number;
}

export declare const WindCompass: React.ComponentType<WindCompassProps>;
