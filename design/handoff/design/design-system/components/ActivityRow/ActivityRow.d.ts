import * as React from 'react';

/**
 * ActivityRow — from @oratge/ui@0.1.0.
 */
export interface ActivityRowProps {
  sport: "wing" | "surf" | "bike" | "run" | "hike";
  /** Today's rating 0–5. */
  rating: number;
  /** Best window, e.g. "13–17 h", "all day", or "—". */
  window: string;
  /** Short reason, e.g. "side-on SW 16–19 kn". */
  reason: string;
  /** Overrides the leading glyph (defaults to the sport's main driver: wind, waves, sun, UV, storm). */
  icon?: "sun" | "partly" | "cloud" | "rain" | "storm" | "bolt" | "wind" | "wave" | "heat" | "snow" | "uv" | "night" | "fog";
}

export declare const ActivityRow: React.ComponentType<ActivityRowProps>;
