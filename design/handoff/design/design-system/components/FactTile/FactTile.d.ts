import * as React from 'react';

/**
 * FactTile — from @oratge/ui@0.1.0.
 */
export interface FactTileProps {
  /** Uppercase label, e.g. "Water". */
  label: string;
  /** The value, e.g. "18.6°" or "5 m → 4 m". */
  value: React.ReactNode;
  /** Small explanation, e.g. "3/2 suit". */
  sub?: string;
  /** Colours the value with a weather accent — only when the value IS that quantity. */
  accent?: "sun" | "storm" | "wind" | "heat" | "snow" | "water" | "neutral";
  /** "lg" = a key number (36px value): one strip of 2–4 per screen for the data that decides the plan. */
  size?: "md" | "lg";
}

export declare const FactTile: React.ComponentType<FactTileProps>;
