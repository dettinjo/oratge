BottomNav from @oratge/ui. Use via `window.OratgeUI.BottomNav` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

App navigation with the four top-level sections. Sits at the bottom of every phone screen.

## Props

```ts
interface BottomNavProps {
  active: "Today" | "Activities" | "Map" | "Spots";
  onSelect?: (tab: NavTab) => void;
}
```

## Examples

### Today

```jsx
() => <div style={{ width: 390 }}><BottomNav active="Today" /></div>
```

### Activities

```jsx
() => <div style={{ width: 390 }}><BottomNav active="Activities" /></div>
```
