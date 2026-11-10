WarningBanner from @oratge/ui. Use via `window.OratgeUI.WarningBanner` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Official Meteocat warning. Warning colours are reserved for this component and the map overlay; always shown with the triangle icon and level name.

## Props

```ts
interface WarningBannerProps {
  /** Meteocat warning level. */
  level: "yellow" | "orange" | "red";
  /** e.g. "Orange warning · Sea state" */
  title: string;
  /** Area, time window and threshold, e.g. "Maresme coast · Wed 12–20 h · waves up to 2.5 m". */
  detail?: string;
  /** `pre` renders a lighter pre-warning (preavís) variant. */
  kind?: "warning" | "pre";
}
```

## Examples

### Orange

```jsx
() => <div style={{ width: 350 }}><WarningBanner level="orange" title="Orange warning · Sea state" detail="Maresme coast · Wed 12–20 h · waves up to 2.5 m" /></div>
```

### Levels

```jsx
() => (
  <div style={{ width: 350, display: 'flex', flexDirection: 'column', gap: 10 }}>
    <WarningBanner level="yellow" title="Yellow warning · Wind" detail="Barcelona coast · Tue 14–22 h · gusts above 70 km/h" />
    <WarningBanner level="orange" title="Orange warning · Rain" detail="Garrotxa · Thu 06–18 h · 40 mm in 1 h" />
    <WarningBanner level="red" title="Red warning · Snow" detail="Val d'Aran · Fri · 60 cm above 1000 m" />
  </div>
)
```

### PreWarning

```jsx
() => <div style={{ width: 350 }}><WarningBanner level="yellow" kind="pre" title="Pre-warning · Wed" detail="Yellow wind warning likely for the Barcelona coast" /></div>
```
