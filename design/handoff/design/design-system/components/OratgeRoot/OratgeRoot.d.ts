import * as React from 'react';

/**
 * OratgeRoot — from @oratge/ui@0.1.0.
 */
export interface OratgeRootProps {
  children?: React.ReactNode;
  /** Adds the standard 20px screen padding. */
  padded?: boolean;
  /** Fixed width, e.g. 390 for a phone screen. */
  width?: string | number;
  style?: CSSProperties;
}

export declare const OratgeRoot: React.ComponentType<OratgeRootProps>;
