import * as React from 'react';

/**
 * WeatherIcon — from @oratge/ui@0.1.0.
 */
export interface WeatherIconProps {
  kind: "sun" | "partly" | "cloud" | "rain" | "storm" | "bolt" | "wind" | "wave" | "heat" | "snow" | "uv" | "night" | "fog";
  /** Pixel size (square). Default 24. */
  size?: number;
}

export declare const WeatherIcon: React.ComponentType<WeatherIconProps>;
