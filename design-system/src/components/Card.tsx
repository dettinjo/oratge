import type { ReactNode, CSSProperties } from 'react';

export interface CardProps {
  children?: ReactNode;
  /** `surface` (default) or `raised` for a card nested inside another card. */
  tone?: 'surface' | 'raised';
  /** Smaller 12px padding. */
  tight?: boolean;
  style?: CSSProperties;
}

/** Rounded surface (20px radius, no shadow) that groups related content. */
export function Card({ children, tone = 'surface', tight, style }: CardProps) {
  return <div className={'og-card' + (tone === 'raised' ? ' og-raised' : '') + (tight ? ' og-tight' : '')} style={style}>{children}</div>;
}
