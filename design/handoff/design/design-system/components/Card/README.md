Card from @oratge/ui. Use via `window.OratgeUI.Card` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Rounded surface (20px radius, no shadow) that groups related content.

## Props

```ts
interface CardProps {
  children?: React.ReactNode;
  /** `surface` (default) or `raised` for a card nested inside another card. */
  tone?: "surface" | "raised";
  /** Smaller 12px padding. */
  tight?: boolean;
  style?: CSSProperties;
}
```

## Examples

### Surface

```jsx
() => (
  <div style={{ width: 350 }}><Card><div style={{ fontWeight: 600 }}>Start 11° feels-like · 6 kn NW</div>
    <div style={{ color: '#B0A596', fontSize: 13, marginTop: 4, lineHeight: 1.5 }}>Long-finger gloves and a gilet until 10 h; arm warmers you can pocket.</div></Card></div>
)
```

### RaisedInside

```jsx
() => (
  <div style={{ width: 350 }}><Card><div style={{ fontSize: 15, fontWeight: 600, marginBottom: 10 }}>Gear for 75 kg</div>
    <Card tone="raised" tight><div style={{ fontSize: 13 }}>5 m wing until 15 h, then 4 m when gusts pass 22 kn</div></Card></Card></div>
)
```

### Tight

```jsx
() => <div style={{ width: 200 }}><Card tight><FactTile label="Sunset" value="17:35" sub="last light 18:03" /></Card></div>
```
