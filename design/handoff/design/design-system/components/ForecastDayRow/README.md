ForecastDayRow from @oratge/ui. Use via `window.OratgeUI.ForecastDayRow` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

One line of the 7-day list: day, sky, rain chance, min—max on a shared temperature scale.

## Props

```ts
interface ForecastDayRowProps {
  day: string;
  sky: "sun" | "partly" | "cloud" | "rain" | "storm" | "bolt" | "wind" | "wave" | "heat" | "snow" | "uv" | "night" | "fog";
  /** Rain probability %; hidden when 0. */
  rainChance: number;
  min: number;
  max: number;
  /** Week-wide min/max so every row's bar shares one scale. */
  scale: [number, number];
}
```

## Examples

### SevenDays

```jsx
() => <div style={{ width: 350 }}>{week.map(([d, s, p, a, b]) => <ForecastDayRow key={d} day={d} sky={s} rainChance={p} min={a} max={b} scale={[8, 22]} />)}</div>
```
