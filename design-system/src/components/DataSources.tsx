import type { ReactNode } from 'react';

export interface DataSourcesProps { children?: ReactNode }

/** Footnote listing the data behind a screen (Meteocat endpoints, stations, gap fillers). Required at the end of every planner — attribution and trust. */
export function DataSources({ children }: DataSourcesProps) {
  return <div className="og-src">Data: {children}</div>;
}
