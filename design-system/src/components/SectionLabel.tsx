import type { ReactNode } from 'react';

export interface SectionLabelProps { children?: ReactNode }

/** Small uppercase section heading, e.g. "Hour by hour" or "What to wear". */
export function SectionLabel({ children }: SectionLabelProps) {
  return <div className="og-label">{children}</div>;
}
