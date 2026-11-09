import type { ReactNode, CSSProperties } from 'react';

export interface OratgeRootProps {
  children?: ReactNode;
  /** Adds the standard 20px screen padding. */
  padded?: boolean;
  /** Fixed width, e.g. 390 for a phone screen. */
  width?: number | string;
  style?: CSSProperties;
}

/** Root wrapper for every Oratge screen: warm dark background, DM Sans, tabular figures. Wrap every design in it. */
export function OratgeRoot({ children, padded, width, style }: OratgeRootProps) {
  return <div className={'og-root' + (padded ? ' og-padded' : '')} style={{ width, ...style }}>{children}</div>;
}
