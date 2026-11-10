OratgeRoot from @oratge/ui. Use via `window.OratgeUI.OratgeRoot` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Root wrapper for every Oratge screen: warm dark background, DM Sans, tabular figures. Wrap every design in it.

## Props

```ts
interface OratgeRootProps {
  children?: React.ReactNode;
  /** Adds the standard 20px screen padding. */
  padded?: boolean;
  /** Fixed width, e.g. 390 for a phone screen. */
  width?: string | number;
  style?: CSSProperties;
}
```

## Examples

### PhoneScreen

```jsx
() => (
  <OratgeRoot padded width={390}>
    <CurrentConditions place="Barcelona" source="Meteocat · Zoo station · 8 min ago" sky="partly" temp={18} summary="Mostly sunny" feels={17} min={11} max={21} wind="SW 14 kn · gusts 21" />
    <SectionLabel>Today for you</SectionLabel>
    <ActivityRow sport="wing" rating={4} window="13–17 h" reason="side-on SW 16–19 kn" />
    <ActivityRow sport="bike" rating={5} window="all day" reason="dry roads · light wind" />
  </OratgeRoot>
)
```
