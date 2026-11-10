import * as React from 'react';

/**
 * RatingDots — from @oratge/ui@0.1.0.
 */
export interface RatingDotsProps {
  /** Condition rating 0–5 (0 = not possible). */
  value: number;
  size?: "sm" | "lg";
  /** Show the word (Poor … Epic) after the dots. */
  showWord?: boolean;
}

export declare const RatingDots: React.ComponentType<RatingDotsProps>;
