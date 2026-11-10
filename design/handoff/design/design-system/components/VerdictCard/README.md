VerdictCard from @oratge/ui. Use via `window.OratgeUI.VerdictCard` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Top-of-planner verdict: rating, the best window and the reasoning. One per daily planner.

## Props

```ts
interface VerdictCardProps {
  /** Day rating 0–5 for the chosen sport. */
  rating: number;
  /** Headline plan, e.g. "Best 13–17 h · peak 14–16 h" or "Leave 09:00 → back 12:00". */
  best: string;
  /** One or two sentences explaining why. */
  summary: string;
  /** e.g. "High confidence" — how much the forecasts agree. */
  confidence?: string;
}
```

## Examples

### Wing

```jsx
() => <div style={{ width: 350 }}><VerdictCard rating={4} best="Best 13–17 h · peak 14–16 h" confidence="High confidence" summary="Side-on SW building to 16–19 kn, gusts ≤ 24. Chop rising to 0.8 m. Morning offshore NW, so stay ashore before 10 h." /></div>
```

### Bike

```jsx
() => <div style={{ width: 350 }}><VerdictCard rating={5} best="Leave 09:00 → back 12:00" confidence="High confidence" summary="Dry window before the 13 h showers. NW tailwind on the climb, roads dry from 09 h." /></div>
```

### Hike

```jsx
() => <div style={{ width: 350 }}><VerdictCard rating={2} best="Start 07:30 · turn back by 12:00" confidence="Medium confidence" summary="Clear, cold morning, −1° and NW 22 kn on the summit. 45 % storm risk at 14 h." /></div>
```
