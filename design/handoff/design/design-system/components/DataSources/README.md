DataSources from @oratge/ui. Use via `window.OratgeUI.DataSources` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Footnote listing the data behind a screen (Meteocat endpoints, stations, gap fillers). Required at the end of every planner — attribution and trust.

## Props

```ts
interface DataSourcesProps {
  children?: React.ReactNode;
}
```

## Examples

### WingPlanner

```jsx
() => <div style={{ width: 350 }}><DataSources>beach forecast Castelldefels (hourly wind, waves, water), XEMA wind and gusts, pressure, municipal hourly, UV, lightning, warnings; Open-Meteo gust forecast</DataSources></div>
```
