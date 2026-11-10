import * as React from 'react';

/**
 * AltitudeProfile — from @oratge/ui@0.1.0.
 */
export interface AltitudeProfileProps {
  /** Points from valley to summit. */
  points: AltitudePoint[];
  /** Snow level in m (frost line). */
  snowLevel?: number;
  width?: number;
}

export declare const AltitudeProfile: React.ComponentType<AltitudeProfileProps>;

/**
 * CalendarHeatmap — from @oratge/ui@0.1.0.
 */
export interface CalendarHeatmapProps {
  /** weeks[w][d] = level 0–5 (0 = none) for each day, Monday first. */
  weeks: number[][];
  /** Labels spaced along the bottom, e.g. ["May", "Jun", …]. */
  months?: string[];
  /** Legend end labels, e.g. ["0 h", "6+ h"]. */
  legend?: [string, string];
  cell?: number;
}

export declare const CalendarHeatmap: React.ComponentType<CalendarHeatmapProps>;

/**
 * HourChart — from @oratge/ui@0.1.0.
 */
export interface HourChartProps {
  /** Column hours, e.g. [7, 8, …, 20]. */
  hours: number[];
  rows: HourRow[];
  /** Recommended window [startHour, endHour] — drawn as a dashed frame. */
  best?: [number, number];
  /** Decimal hours; columns outside daylight are shaded. */
  sunrise?: number;
  sunset?: number;
  width?: number;
}

export declare const HourChart: React.ComponentType<HourChartProps>;

/**
 * MonthBars — from @oratge/ui@0.1.0.
 */
export interface MonthBarsProps {
  /** 12 monthly values, January first. */
  values: number[];
  accent?: "sun" | "storm" | "wind" | "heat" | "snow" | "water" | "neutral";
  /** Index of the month to emphasise and label (e.g. the best month). */
  highlight?: number;
  /** Index of the current month (bold axis letter). */
  current?: number;
  width?: number;
}

export declare const MonthBars: React.ComponentType<MonthBarsProps>;

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

/**
 * RouteWind — from @oratge/ui@0.1.0.
 */
export interface RouteWindProps {
  /** Route polyline in chart coordinates (0–322 × 0–150). Closed loops repeat the first point at the end. */
  points: [number, number][];
  /** Wind direction FROM, degrees. */
  windFrom: number;
  /** e.g. "NW 7 kn". */
  windLabel: string;
  /** Headline, e.g. "58 % tailwind on the climb". */
  title?: string;
  /** Labels placed at points: [x, y, text]. */
  labels?: [number, number, string][];
  width?: number;
}

export declare const RouteWind: React.ComponentType<RouteWindProps>;

/**
 * SwellWindow — from @oratge/ui@0.1.0.
 */
export interface SwellWindowProps {
  /** Swell direction FROM, degrees. */
  swellFrom: number;
  /** Directions the beach is open to, [from, to] clockwise in degrees, e.g. [40, 180]. */
  exposure: [number, number];
  size?: number;
}

export declare const SwellWindow: React.ComponentType<SwellWindowProps>;

/**
 * TrendLine — from @oratge/ui@0.1.0.
 */
export interface TrendLineProps {
  /** Main series (solid). */
  values: number[];
  accent: "sun" | "storm" | "wind" | "heat" | "snow" | "water" | "neutral";
  /** Optional upper band in the same unit (e.g. gusts). */
  band?: number[];
  /** Optional comparison series, dashed neutral (e.g. the forecast vs measured). */
  compare?: number[];
  /** Mark this index with a dot and `nowLabel`. */
  nowIndex?: number;
  nowLabel?: string;
  /** Left/right caption under the chart, e.g. ["−12 h", "+12 h"]. */
  caption?: [string, string];
  /** Start/end value labels. */
  endLabels?: [string, string];
  min?: number;
  max?: number;
  width?: number;
  height?: number;
}

export declare const TrendLine: React.ComponentType<TrendLineProps>;

/**
 * WaveBars — from @oratge/ui@0.1.0.
 */
export interface WaveBarsProps {
  /** Significant wave height (m) per slot, e.g. every 3 h. */
  heights: number[];
  /** Wave period (s) per slot, printed above bars. */
  periods: number[];
  /** Wind direction FROM per slot (degrees) — sage-teal arrows below the bars. */
  windFrom?: number[];
  /** Day labels; slots are split evenly between them. */
  days?: string[];
  /** Slot indexes to emphasise as the best session. */
  best?: number[];
  /** Axis max in m (default 1.6). */
  max?: number;
  width?: number;
}

export declare const WaveBars: React.ComponentType<WaveBarsProps>;

/**
 * WindBand — from @oratge/ui@0.1.0.
 */
export interface WindBandProps {
  /** Mean wind per hour (kn), any length (e.g. 72 for 3 days). */
  mean: number[];
  /** Gusts per hour (kn), same length. */
  gust: number[];
  /** Direction FROM per hour, degrees — arrows drawn every 6 h. */
  directions?: number[];
  /** The rider's usable range, hatched, e.g. [14, 24]. */
  range?: [number, number];
  /** Day labels, one per 24 values. */
  days?: string[];
  /** [startIndex, endIndex) hour ranges to shade as night. */
  night?: [number, number][];
  /** [startIndex, endIndex] to frame as the best window. */
  best?: [number, number];
  /** Axis max in kn (default 35). */
  max?: number;
  width?: number;
  height?: number;
}

export declare const WindBand: React.ComponentType<WindBandProps>;

/**
 * WindCompass — from @oratge/ui@0.1.0.
 */
export interface WindCompassProps {
  /** Direction the wind comes FROM, degrees. */
  from?: number;
  /** Same as `from`; use this where `from` is a reserved attribute (e.g. a Design canvas). */
  direction?: number;
  /** Mean speed (kn), shown in the centre. */
  speed: number;
  /** Direction the beach faces (towards the sea), degrees. Sectors: from the sea = rideable, from land = offshore. */
  shoreFacing: number;
  /** Caption under the dial, e.g. "live · side-shore". */
  caption?: string;
  size?: number;
}

export declare const WindCompass: React.ComponentType<WindCompassProps>;

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

/**
 * BottomNav — from @oratge/ui@0.1.0.
 */
export interface BottomNavProps {
  active: "Today" | "Activities" | "Map" | "Spots";
  onSelect?: (tab: NavTab) => void;
}

export declare const BottomNav: React.ComponentType<BottomNavProps>;

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

/**
 * ChipGroup — from @oratge/ui@0.1.0.
 */
export interface ChipGroupProps {
  options: string[];
  selected: string;
  /** Optional leading label, e.g. "Ride length". */
  label?: string;
  onSelect?: (option: string) => void;
}

export declare const ChipGroup: React.ComponentType<ChipGroupProps>;

/**
 * CurrentConditions — from @oratge/ui@0.1.0.
 */
export interface CurrentConditionsProps {
  place: string;
  /** Source line, e.g. "Meteocat · Zoo station · 8 min ago". */
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

/**
 * DataSources — from @oratge/ui@0.1.0.
 */
export interface DataSourcesProps {
  children?: React.ReactNode;
}

export declare const DataSources: React.ComponentType<DataSourcesProps>;

/**
 * DayTabs — from @oratge/ui@0.1.0.
 */
export interface DayTabsProps {
  days: DayTab[];
  /** Index of the selected day. */
  selected: number;
  onSelect?: (index: number) => void;
}

export declare const DayTabs: React.ComponentType<DayTabsProps>;

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

/**
 * OratgeRoot — from @oratge/ui@0.1.0.
 */
export interface OratgeRootProps {
  children?: React.ReactNode;
  /** Adds the standard 20px screen padding. */
  padded?: boolean;
  /** Fixed width, e.g. 390 for a phone screen. */
  width?: string | number;
  style?: CSSProperties;
}

export declare const OratgeRoot: React.ComponentType<OratgeRootProps>;

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

/**
 * RatingStrip — from @oratge/ui@0.1.0.
 */
export interface RatingStripProps {
  /** One rating (0–5) per slot, usually per hour. */
  values: number[];
  /** Optional text under the strip, left / centre / right (e.g. ["08 h", "today", "22 h"]). */
  caption?: [string, string, string];
  height?: number;
}

export declare const RatingStrip: React.ComponentType<RatingStripProps>;

/**
 * SectionLabel — from @oratge/ui@0.1.0.
 */
export interface SectionLabelProps {
  children?: React.ReactNode;
}

export declare const SectionLabel: React.ComponentType<SectionLabelProps>;

/**
 * SpotCard — from @oratge/ui@0.1.0.
 */
export interface SpotCardProps {
  name: string;
  /** e.g. "Wing · flatwater" or "Hike · 1706 m". */
  kind: string;
  /** Live wind in kn at the linked station. */
  wind: number;
  gust: number;
  /** Direction the wind comes FROM, degrees. */
  windFrom: number;
  /** Today's hourly ratings (e.g. 08–22 h in 2 h steps). */
  today: number[];
  /** Best window text, e.g. "13–17 h". */
  window: string;
  /** Best rating today, colours the window. */
  rating: number;
}

export declare const SpotCard: React.ComponentType<SpotCardProps>;

/**
 * VerdictCard — from @oratge/ui@0.1.0.
 */
export interface VerdictCardProps {
  /** Day rating 0–5 for the chosen sport. */
  rating: number;
  /** Headline plan, e.g. "Best 13–17 h · peak 14–16 h" or "Leave 09:00 → back 12:00". */
  best: string;
  /** One or two sentences explaining why. */
  summary: string;
  /** e.g. "High confidence" — how much the forecasts agree. */
  confidence?: string;
}

export declare const VerdictCard: React.ComponentType<VerdictCardProps>;

/**
 * WarningBanner — from @oratge/ui@0.1.0.
 */
export interface WarningBannerProps {
  /** Meteocat warning level. */
  level: "yellow" | "orange" | "red";
  /** e.g. "Orange warning · Sea state" */
  title: string;
  /** Area, time window and threshold, e.g. "Maresme coast · Wed 12–20 h · waves up to 2.5 m". */
  detail?: string;
  /** `pre` renders a lighter pre-warning (preavís) variant. */
  kind?: "warning" | "pre";
}

export declare const WarningBanner: React.ComponentType<WarningBannerProps>;

/**
 * WeatherIcon — from @oratge/ui@0.1.0.
 */
export interface WeatherIconProps {
  kind: "sun" | "partly" | "cloud" | "rain" | "storm" | "bolt" | "wind" | "wave" | "heat" | "snow" | "uv" | "night" | "fog";
  /** Pixel size (square). Default 24. */
  size?: number;
}

export declare const WeatherIcon: React.ComponentType<WeatherIconProps>;
