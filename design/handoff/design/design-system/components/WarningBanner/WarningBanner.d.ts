import * as React from 'react';

/**
 * WarningBanner — from @oratge/ui@0.1.0.
 */
export interface WarningBannerProps {
  /** Meteocat warning level. */
  level: "yellow" | "orange" | "red";
  /** e.g. "Orange warning · Sea state" */
  title: string;
  /** Area, time window and threshold, e.g. "Maresme coast · Wed 12–20 h · waves up to 2.5 m". */
  detail?: string;
  /** `pre` renders a lighter pre-warning (preavís) variant. */
  kind?: "warning" | "pre";
}

export declare const WarningBanner: React.ComponentType<WarningBannerProps>;
