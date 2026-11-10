AltitudeProfile from @oratge/ui. Use via `window.OratgeUI.AltitudeProfile` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Hike chart: temperature by altitude (valley → hut → summit) with the 0 °C line and snow level.

## Props

```ts
interface AltitudeProfileProps {
  /** Points from valley to summit. */
  points: AltitudePoint[];
  /** Snow level in m (frost line). */
  snowLevel?: number;
  width?: number;
}
```

## Examples

### Pedraforca

```jsx
() => <AltitudeProfile snowLevel={2300} points={[{ altitude: 1215, temp: 7, label: 'Saldes' }, { altitude: 1640, temp: 5, label: 'Refugi' }, { altitude: 2100, temp: 2 }, { altitude: 2506, temp: -1, label: 'Summit' }]} />
```
