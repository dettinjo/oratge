WeatherIcon from @oratge/ui. Use via `window.OratgeUI.WeatherIcon` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Weather glyph with the accent colour that matches its meaning (sun = honey, rain/waves = sea blue, storm = lavender, wind = sage-teal, heat = apricot). Use for sky state and activity markers; never recolour.

## Props

```ts
interface WeatherIconProps {
  kind: "sun" | "partly" | "cloud" | "rain" | "storm" | "bolt" | "wind" | "wave" | "heat" | "snow" | "uv" | "night" | "fog";
  /** Pixel size (square). Default 24. */
  size?: number;
}
```

## Examples

### AllKinds

```jsx
() => (
  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 64px)', gap: '14px 8px' }}>
    {all.map(([k, n]) => <div key={k} style={{ textAlign: 'center' }}><WeatherIcon kind={k} size={30} /><div style={{ fontSize: 10.5, color: '#7E7468', marginTop: 4 }}>{n}</div></div>)}
  </div>
)
```

### Sizes

```jsx
() => <div style={{ display: 'flex', gap: 16, alignItems: 'end' }}><WeatherIcon kind="partly" size={18} /><WeatherIcon kind="partly" size={30} /><WeatherIcon kind="partly" size={62} /></div>
```
