import * as React from 'react';

/**
 * CurrentConditions — from @oratge/ui@0.1.0.
 */
export interface CurrentConditionsProps {
  place: string;
  /** Source line, e.g. "Meteocat · el Raval station · 8 min ago". */
  source: string;
  sky: "sun" | "partly" | "cloud" | "rain" | "storm" | "bolt" | "wind" | "wave" | "heat" | "snow" | "uv" | "night" | "fog";
  /** Current temperature °C. */
  temp: number;
  /** e.g. "Mostly sunny". */
  summary: string;
  feels: number;
  min: number;
  max: number;
  /** e.g. "SW 14 kn · gusts 21". */
  wind: string;
}

export declare const CurrentConditions: React.ComponentType<CurrentConditionsProps>;
