CalendarHeatmap from @oratge/ui. Use via `window.OratgeUI.CalendarHeatmap` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

History heatmap (e.g. rideable hours per day) on the sage rating ramp.

## Props

```ts
interface CalendarHeatmapProps {
  /** weeks[w][d] = level 0–5 (0 = none) for each day, Monday first. */
  weeks: number[][];
  /** Labels spaced along the bottom, e.g. ["May", "Jun", …]. */
  months?: string[];
  /** Legend end labels, e.g. ["0 h", "6+ h"]. */
  legend?: [string, string];
  cell?: number;
}
```

## Examples

### RideableHours

```jsx
() => <CalendarHeatmap weeks={weeks} months={['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov']} legend={['0 h', '6+ h']} />
```
