RatingStrip from @oratge/ui. Use via `window.OratgeUI.RatingStrip` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Compact horizontal bar of rating cells — "how good is each hour". Used on spot cards and the go-window.

## Props

```ts
interface RatingStripProps {
  /** One rating (0–5) per slot, usually per hour. */
  values: number[];
  /** Optional text under the strip, left / centre / right (e.g. ["08 h", "today", "22 h"]). */
  caption?: [string, string, string];
  height?: number;
}
```

## Examples

### WingDay

```jsx
() => <div style={{ width: 320 }}><RatingStrip values={[0, 1, 3, 4, 5, 5, 4, 2]} caption={['08 h', "today's rating", '22 h']} /></div>
```

### AllDay

```jsx
() => <div style={{ width: 320 }}><RatingStrip values={[5, 5, 5, 5, 5, 4, 4, 4]} height={12} /></div>
```

### Hourly

```jsx
() => <div style={{ width: 320 }}><RatingStrip values={[0, 0, 0, 1, 2, 3, 4, 5, 5, 4, 2, 0, 0, 0]} caption={['07 h', 'Tue', '20 h']} /></div>
```
