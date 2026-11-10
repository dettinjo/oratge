MonthBars from @oratge/ui. Use via `window.OratgeUI.MonthBars` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Climatology bars per month, e.g. rideable days per month at a station.

## Props

```ts
interface MonthBarsProps {
  /** 12 monthly values, January first. */
  values: number[];
  accent?: "sun" | "storm" | "wind" | "heat" | "snow" | "water" | "neutral";
  /** Index of the month to emphasise and label (e.g. the best month). */
  highlight?: number;
  /** Index of the current month (bold axis letter). */
  current?: number;
  width?: number;
}
```

## Examples

### RideableDays

```jsx
() => <MonthBars values={[6.1, 7.8, 10.2, 12.4, 10.9, 8.3, 7.1, 6.4, 7.0, 8.8, 8.1, 6.6]} highlight={3} current={10} />
```

### RainDays

```jsx
() => <MonthBars accent="water" values={[5, 4, 6, 7, 6, 4, 2, 4, 6, 8, 6, 5]} highlight={9} current={10} />
```
