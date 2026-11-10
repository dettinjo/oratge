SpotCard from @oratge/ui. Use via `window.OratgeUI.SpotCard` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Saved place with live wind and today's rating strip. Stack in a column on the Spots screen.

## Props

```ts
interface SpotCardProps {
  name: string;
  /** e.g. "Wing · flatwater" or "Hike · 1706 m". */
  kind: string;
  /** Live wind in kn at the linked station. */
  wind: number;
  gust: number;
  /** Direction the wind comes FROM, degrees. */
  windFrom: number;
  /** Today's hourly ratings (e.g. 08–22 h in 2 h steps). */
  today: number[];
  /** Best window text, e.g. "13–17 h". */
  window: string;
  /** Best rating today, colours the window. */
  rating: number;
}
```

## Examples

### WingSpot

```jsx
() => <div style={{ width: 350 }}><SpotCard name="Castelldefels" kind="Wing · flatwater" wind={14} gust={21} windFrom={225} today={[0, 1, 3, 4, 4, 3, 0, 0]} window="13–17 h" rating={4} /></div>
```

### SpotList

```jsx
() => (
  <div style={{ width: 350, display: 'flex', flexDirection: 'column', gap: 10 }}>
    <SpotCard name="Ocata" kind="Surf · beach" wind={6} gust={9} windFrom={330} today={[3, 3, 2, 1, 1, 1, 0, 0]} window="08–11 h" rating={3} />
    <SpotCard name="Collserola loop" kind="Bike · 42 km" wind={7} gust={12} windFrom={240} today={[5, 5, 5, 5, 5, 4, 4, 4]} window="all day" rating={5} />
    <SpotCard name="Montseny · Turó de l'Home" kind="Hike · 1706 m" wind={22} gust={34} windFrom={300} today={[3, 3, 2, 1, 1, 0, 0, 0]} window="until 13 h" rating={2} />
  </div>
)
```
