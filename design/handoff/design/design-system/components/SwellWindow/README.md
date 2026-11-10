SwellWindow from @oratge/ui. Use via `window.OratgeUI.SwellWindow` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Surf compass: the sea-facing window shaded sea blue, the swell arrow travelling towards the beach. Shows at a glance whether the swell can reach the spot.

## Props

```ts
interface SwellWindowProps {
  /** Swell direction FROM, degrees. */
  swellFrom: number;
  /** Directions the beach is open to, [from, to] clockwise in degrees, e.g. [40, 180]. */
  exposure: [number, number];
  size?: number;
}
```

## Examples

### DirectHit

```jsx
() => <SwellWindow swellFrom={95} exposure={[40, 180]} />
```

### Blocked

```jsx
() => <SwellWindow swellFrom={300} exposure={[40, 180]} />
```
