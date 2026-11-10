import * as React from 'react';

/**
 * ForecastDayRow — from @oratge/ui@0.1.0.
 */
export interface ForecastDayRowProps {
  day: string;
  sky: "sun" | "partly" | "cloud" | "rain" | "storm" | "bolt" | "wind" | "wave" | "heat" | "snow" | "uv" | "night" | "fog";
  /** Rain probability %; hidden when 0. */
  rainChance: number;
  min: number;
  max: number;
  /** Week-wide min/max so every row's bar shares one scale. */
  scale: [number, number];
}

export declare const ForecastDayRow: React.ComponentType<ForecastDayRowProps>;
