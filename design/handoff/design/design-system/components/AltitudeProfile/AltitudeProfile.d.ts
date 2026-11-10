import * as React from 'react';

/**
 * AltitudeProfile — from @oratge/ui@0.1.0.
 */
export interface AltitudeProfileProps {
  /** Points from valley to summit. */
  points: AltitudePoint[];
  /** Snow level in m (frost line). */
  snowLevel?: number;
  width?: number;
}

export declare const AltitudeProfile: React.ComponentType<AltitudeProfileProps>;
