SectionLabel from @oratge/ui. Use via `window.OratgeUI.SectionLabel` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Small uppercase section heading, e.g. "Hour by hour" or "What to wear".

## Props

```ts
interface SectionLabelProps {
  children?: React.ReactNode;
}
```

## Examples

### AboveCard

```jsx
() => (
  <div style={{ width: 350 }}><SectionLabel>What to wear</SectionLabel>
    <Card><div style={{ fontSize: 13 }}>Long sleeve and shorts · 0.4 L water</div></Card></div>
)
```

### Labels

```jsx
() => <div style={{ width: 350 }}><SectionLabel>Hour by hour</SectionLabel><SectionLabel>Water · light · safety</SectionLabel><SectionLabel>Snow · lightning · ground</SectionLabel></div>
```
