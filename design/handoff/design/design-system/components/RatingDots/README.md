RatingDots from @oratge/ui. Use via `window.OratgeUI.RatingDots` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Five dots on the sage rating ramp. The filled count AND the colour carry the rating, so it never relies on colour alone.

## Props

```ts
interface RatingDotsProps {
  /** Condition rating 0–5 (0 = not possible). */
  value: number;
  size?: "sm" | "lg";
  /** Show the word (Poor … Epic) after the dots. */
  showWord?: boolean;
}
```

## Examples

### Scale

```jsx
() => (
  <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
    {[1, 2, 3, 4, 5].map(v => <RatingDots key={v} value={v} showWord />)}
  </div>
)
```

### Large

```jsx
() => <RatingDots value={4} size="lg" showWord />
```

### NotPossible

```jsx
() => <RatingDots value={0} showWord />
```
