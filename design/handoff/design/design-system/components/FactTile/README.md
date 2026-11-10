FactTile from @oratge/ui. Use via `window.OratgeUI.FactTile` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Single key fact. Lay out in 2- or 4-column grids.

## Props

```ts
interface FactTileProps {
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
```

## Examples

### FourUp

```jsx
() => (
  <div style={{ width: 350, display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 8 }}>
    <FactTile label="Water" value="18.6°" sub="3/2 suit" /><FactTile label="Sunset" value="17:35" sub="last light 18:03" />
    <FactTile label="Lightning" value="none" sub="50 km · 24 h" /><FactTile label="UV max" value="2" sub="low" />
  </div>
)
```

### TwoUp

```jsx
() => (
  <div style={{ width: 350, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
    <FactTile label="Wing" value="5 m → 4 m" sub="4 m when gusts > 22" /><FactTile label="Roads" value="dry from 09 h" sub="3.2 mm overnight" />
  </div>
)
```

### Accented

```jsx
() => (
  <div style={{ width: 350, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
    <FactTile label="Wave height" value="0.8 m" sub="buoy · 25 min ago" accent="water" /><FactTile label="Gusts" value="21 kn" sub="SW" accent="wind" />
  </div>
)
```
