import * as React from 'react';

/**
 * Card — from @oratge/ui@0.1.0.
 */
export interface CardProps {
  children?: React.ReactNode;
  /** `surface` (default) or `raised` for a card nested inside another card. */
  tone?: "surface" | "raised";
  /** Smaller 12px padding. */
  tight?: boolean;
  style?: CSSProperties;
}

export declare const Card: React.ComponentType<CardProps>;
