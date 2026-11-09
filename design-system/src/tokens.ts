/** Oratge design tokens. Mirrors the CSS custom properties in styles.css (prefix `--og-`). */
export const colors = {
  bg: '#15130F', surface: '#1E1B17', surface2: '#27231E', line: '#36312A', night: '#1A1814', empty: '#2A261F',
  text: '#F1EBE2', text2: '#B0A596', text3: '#7E7468', sand: '#D9B98A',
  wind: '#62C7A2', heat: '#F39A70', water: '#8AAEF2', sun: '#EAC160', storm: '#BA9BF1', snow: '#D7E3F0', cloud: '#A79E92',
  warnYellow: '#F4D266', warnOrange: '#EF8440', warnRed: '#CF3A78',
} as const;

/** Condition rating ramp, index 0 = rating 1 (poor) … index 4 = rating 5 (epic). Always pair with the dot count. */
export const ratingRamp = ['#4E5246', '#667A5A', '#86A276', '#A9C895', '#D6EBC3'] as const;
/** Wind-speed ramp for maps (kn thresholds <8, 8, 11, 14, 17+). */
export const windRamp = ['#35584C', '#3F7D68', '#4FA184', '#62C7A2', '#B0EBD5'] as const;
export const ratingWords = ['Poor', 'Marginal', 'Fair', 'Good', 'Epic'] as const;

/** One meaning per hue. */
export type Accent = 'wind' | 'heat' | 'water' | 'sun' | 'storm' | 'snow' | 'neutral';
export const accentColor = (a: Accent): string => (a === 'neutral' ? colors.text2 : colors[a]);
export const ratingColor = (r: number): string => (r >= 1 ? ratingRamp[Math.min(5, Math.round(r)) - 1] : colors.empty);
export const windColor = (kn: number): string => windRamp[kn < 8 ? 0 : kn < 11 ? 1 : kn < 14 ? 2 : kn < 17 ? 3 : 4];
export type WarningLevel = 'yellow' | 'orange' | 'red';
export const warningColor = (l: WarningLevel): string => ({ yellow: colors.warnYellow, orange: colors.warnOrange, red: colors.warnRed })[l];
