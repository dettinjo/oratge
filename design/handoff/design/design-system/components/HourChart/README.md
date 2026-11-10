HourChart from @oratge/ui. Use via `window.OratgeUI.HourChart` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

The planner meteogram: every variable as one row on shared hour columns, with night shading and the best window framed.
Compose rows per sport (e.g. wing: icons, rating, wind line with gust band and your range, arrows with shore relation, gusts, waves, air, rain).

## Props

```ts
interface HourChartProps {
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
```

## Examples

### WingFoilDay

```jsx
() => (
  <HourChart hours={hours} best={[13, 17]} rows={[
    { type: 'icons', label: 'Sky', values: ['partly', 'sun', 'sun', 'sun', 'sun', 'partly', 'partly', 'partly', 'partly', 'cloud', 'cloud', 'night', 'night', 'night'] },
    { type: 'rating', label: 'Rating', values: [0, 0, 0, 1, 2, 3, 4, 5, 5, 4, 2, 0, 0, 0] },
    { type: 'line', label: 'Wind', unit: 'kn', accent: 'wind', min: 0, max: 30, range: [14, 24], rangeLabel: 'your range 14–24',
      values: [6, 7, 8, 10, 12, 14, 16, 18, 19, 18, 16, 13, 10, 8], band: [9, 10, 11, 13, 16, 18, 21, 23, 24, 23, 21, 17, 14, 11], labelAt: [8], height: 96 },
    { type: 'arrows', label: 'From', unit: 'vs shore', accent: 'wind', directions: [320, 320, 300, 260, 240, 230, 225, 225, 220, 220, 225, 230, 240, 260],
      shore: ['off', 'off', 'off', 'side', 'side', 'side-on', 'side-on', 'side-on', 'side-on', 'side-on', 'side-on', 'side-on', 'side', 'side'] },
    { type: 'numbers', label: 'Gust', unit: 'kn', values: [9, 10, 11, 13, 16, 18, 21, 23, 24, 23, 21, 17, 14, 11], emphasizeAbove: 22 },
    { type: 'bars', label: 'Waves', unit: 'm', accent: 'water', max: 1.2, labelEvery: 2, decimals: 1, values: [0.3, 0.3, 0.3, 0.4, 0.4, 0.5, 0.6, 0.7, 0.8, 0.8, 0.8, 0.7, 0.7, 0.6], height: 38 },
    { type: 'numbers', label: 'Air', unit: '°C', accent: 'heat', suffix: '°', values: [12, 13, 15, 17, 18, 19, 19, 19, 18, 17, 16, 15, 14, 14] },
    { type: 'bars', label: 'Rain', unit: '%', accent: 'water', max: 100, labelEvery: 2, values: [0, 0, 0, 0, 0, 5, 5, 10, 10, 20, 30, 40, 30, 20] },
  ]} />
)
```

### BikeDay

```jsx
() => (
  <HourChart hours={hours} best={[9, 12]} rows={[
    { type: 'icons', label: 'Sky', values: ['partly', 'sun', 'sun', 'sun', 'partly', 'cloud', 'rain', 'rain', 'rain', 'cloud', 'partly', 'night', 'night', 'night'] },
    { type: 'rating', label: 'Rating', values: [1, 2, 4, 5, 5, 4, 2, 1, 1, 2, 2, 1, 0, 0] },
    { type: 'line', label: 'Temp', unit: '°C', accent: 'heat', min: 6, max: 22, values: [9, 10, 12, 14, 16, 18, 19, 20, 20, 19, 17, 15, 14, 13],
      companion: [7, 8, 11, 13, 15, 17, 18, 19, 19, 18, 16, 14, 12, 11], labelAt: [0, 7], height: 80 },
    { type: 'bars', label: 'Rain', unit: 'mm', accent: 'water', max: 3, labelEvery: 1, decimals: 1, values: [0, 0, 0, 0, 0, 0, 0.4, 2.1, 1.6, 0.3, 0, 0, 0, 0], height: 40 },
    { type: 'category', label: 'Roads', values: ['wet', 'damp', 'dry', 'dry', 'dry', 'dry', 'damp', 'wet', 'wet', 'wet', 'damp', 'damp', 'dry', 'dry'],
      styles: { wet: { color: '#8AAEF2', opacity: 0.9, text: 'wet' }, damp: { color: '#8AAEF2', opacity: 0.45, text: 'damp' }, dry: { color: '#2A261F' } } },
    { type: 'arrows', label: 'Wind', accent: 'wind', directions: [330, 330, 320, 300, 250, 230, 225, 225, 230, 240, 260, 300, 320, 330] },
    { type: 'numbers', label: 'Speed', unit: 'kn', values: [5, 5, 6, 7, 8, 10, 12, 14, 13, 11, 9, 7, 6, 5], emphasizeAbove: 12 },
    { type: 'bars', label: 'UV', accent: 'sun', max: 6, labelEvery: 1, values: [0, 0, 1, 2, 3, 3, 3, 2, 1, 1, 0, 0, 0, 0], height: 30 },
  ]} />
)
```

### HikeSummit

```jsx
() => (
  <HourChart hours={hours} best={[7.5, 12]} sunrise={7.97} sunset={17.4} rows={[
    { type: 'icons', label: 'Sky', values: ['sun', 'sun', 'sun', 'sun', 'partly', 'cloud', 'storm', 'storm', 'storm', 'rain', 'cloud', 'night', 'night', 'night'] },
    { type: 'rating', label: 'Rating', values: [2, 4, 5, 5, 4, 3, 1, 1, 1, 1, 1, 0, 0, 0] },
    { type: 'bars', label: 'Storm', unit: '%', accent: 'storm', max: 70, labelEvery: 1, values: [0, 0, 0, 0, 5, 10, 25, 45, 60, 55, 40, 20, 10, 0], height: 40 },
    { type: 'line', label: 'Wind', unit: 'kn', accent: 'wind', min: 0, max: 45, values: [22, 24, 22, 18, 15, 14, 16, 20, 25, 28, 30, 30, 28, 26],
      band: [31, 34, 31, 25, 21, 20, 22, 28, 35, 39, 42, 42, 39, 36], labelAt: [1, 10], height: 70 },
    { type: 'numbers', label: 'Temp', unit: '°C', accent: 'snow', suffix: '°', values: [-2, -1, 0, 2, 3, 4, 4, 3, 2, 1, 0, -1, -2, -2] },
    { type: 'numbers', label: 'Snow lvl', unit: 'm', accent: 'snow', every: 2, values: [2300, 2300, 2350, 2400, 2400, 2400, 2350, 2300, 2200, 2100, 2000, 1900, 1900, 1900] },
  ]} />
)
```
