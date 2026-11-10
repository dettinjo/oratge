ActivityRow from @oratge/ui. Use via `window.OratgeUI.ActivityRow` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

One row of the Today screen's "Today for you" list. Stack 3–5 in a column; rows draw their own dividers.

## Props

```ts
interface ActivityRowProps {
  sport: "wing" | "surf" | "bike" | "run" | "hike";
  /** Today's rating 0–5. */
  rating: number;
  /** Best window, e.g. "13–17 h", "all day", or "—". */
  window: string;
  /** Short reason, e.g. "side-on SW 16–19 kn". */
  reason: string;
  /** Overrides the leading glyph (defaults to the sport's main driver: wind, waves, sun, UV, storm). */
  icon?: "sun" | "partly" | "cloud" | "rain" | "storm" | "bolt" | "wind" | "wave" | "heat" | "snow" | "uv" | "night" | "fog";
}
```

## Examples

### TodayForYou

```jsx
() => (
  <div style={{ width: 350 }}>
    <ActivityRow sport="wing" rating={4} window="13–17 h" reason="side-on SW 16–19 kn" />
    <ActivityRow sport="surf" rating={1} window="—" reason="flat · 0.3 m" />
    <ActivityRow sport="bike" rating={5} window="all day" reason="dry roads · light wind" />
    <ActivityRow sport="run" rating={4} window="before 11 h" reason="UV 6 from noon" />
    <ActivityRow sport="hike" rating={2} window="until 14 h" reason="storms likely after 15 h" />
  </div>
)
```

### Single

```jsx
() => <div style={{ width: 350 }}><ActivityRow sport="wing" rating={5} window="14–16 h" reason="SW 17–20 kn · steady, gust factor 1.2" /></div>
```
