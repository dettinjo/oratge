WaveBars from @oratge/ui. Use via `window.OratgeUI.WaveBars` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Surf chart: sea-blue wave-height bars with the period on top and wind arrows underneath.

## Props

```ts
interface WaveBarsProps {
  /** Significant wave height (m) per slot, e.g. every 3 h. */
  heights: number[];
  /** Wave period (s) per slot, printed above bars. */
  periods: number[];
  /** Wind direction FROM per slot (degrees) — sage-teal arrows below the bars. */
  windFrom?: number[];
  /** Day labels; slots are split evenly between them. */
  days?: string[];
  /** Slot indexes to emphasise as the best session. */
  best?: number[];
  /** Axis max in m (default 1.6). */
  max?: number;
  width?: number;
}
```

## Examples

### ThreeDays

```jsx
() => <WaveBars heights={hs} periods={per} windFrom={wind} days={['Mon', 'Tue', 'Wed']} best={[8, 9]} />
```

### Flat

```jsx
() => <WaveBars heights={[0.2, 0.2, 0.3, 0.3, 0.3, 0.2, 0.2, 0.2]} periods={[4, 4, 5, 5, 5, 4, 4, 4]} days={['Thu']} />
```
