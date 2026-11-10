RouteWind from @oratge/ui. Use via `window.OratgeUI.RouteWind` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Bike route coloured by wind effect for the chosen start time: tailwind sage-teal, crosswind neutral, headwind apricot.

## Props

```ts
interface RouteWindProps {
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
```

## Examples

### CollserolaLoop

```jsx
() => (
  <RouteWind windFrom={300} windLabel="NW 7 kn" title="58 % tailwind on the climb" labels={[[50, 142, 'start · Sarrià'], [175, 20, 'Tibidabo 512 m']]}
    points={[[40, 120], [70, 95], [95, 70], [130, 45], [175, 30], [220, 28], [262, 42], [285, 70], [280, 102], [250, 122], [205, 132], [150, 135], [100, 132], [60, 128], [40, 120]]} />
)
```
