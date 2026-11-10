DayTabs from @oratge/ui. Use via `window.OratgeUI.DayTabs` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Day picker for daily planners. Each tab carries a rating tick so the best day is visible at a glance.

## Props

```ts
interface DayTabsProps {
  days: DayTab[];
  /** Index of the selected day. */
  selected: number;
  onSelect?: (index: number) => void;
}
```

## Examples

### WeekTuesday

```jsx
() => <div style={{ width: 350 }}><DayTabs days={days} selected={1} /></div>
```

### TodaySelected

```jsx
() => <div style={{ width: 350 }}><DayTabs days={days} selected={0} /></div>
```
