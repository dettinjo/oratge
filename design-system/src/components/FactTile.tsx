import type { ReactNode } from 'react';
import { accentColor, type Accent } from '../tokens';

export interface FactTileProps {
  /** Uppercase label, e.g. "Water". */
  label: string;
  /** The value, e.g. "18.6°" or "5 m → 4 m". */
  value: ReactNode;
  /** Small explanation, e.g. "3/2 suit". */
  sub?: string;
  /** Colours the value with a weather accent — only when the value IS that quantity. */
  accent?: Accent;
}

/** Single key fact. Lay out in 2- or 4-column grids. */
export function FactTile({ label, value, sub, accent }: FactTileProps) {
  return (
    <div className="og-fact">
      <div className="og-fact-label">{label}</div>
      <div className="og-fact-value" style={accent ? { color: accentColor(accent) } : undefined}>{value}</div>
      {sub && <div className="og-fact-sub">{sub}</div>}
    </div>
  );
}
