import * as React from 'react';

/**
 * NextHours — from @oratge/ui@0.1.0.
 */
export interface NextHoursProps {
  /** Hourly temperature (°C), usually 24 values. */
  temps: number[];
  /** Hourly rain probability (%), same length. Drawn as a separate strip — never on the temperature axis. */
  rain: number[];
  /** Hourly sky, same length (icons every 3 h). */
  sky: WeatherKind[];
  /** Hour of the first value, e.g. 10. */
  startHour: number;
  width?: number;
}

export declare const NextHours: React.ComponentType<NextHoursProps>;
