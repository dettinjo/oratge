ChipGroup from @oratge/ui. Use via `window.OratgeUI.ChipGroup` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Single-select pill chips: layer toggles, ride/run length pickers.

## Props

```ts
interface ChipGroupProps {
  options: string[];
  selected: string;
  /** Optional leading label, e.g. "Ride length". */
  label?: string;
  onSelect?: (option: string) => void;
}
```

## Examples

### RideLength

```jsx
() => <div style={{ width: 350 }}><ChipGroup label="Ride length" options={['1 h', '2 h', '3 h', '4 h', '5 h']} selected="3 h" /></div>
```

### MapLayers

```jsx
() => <div style={{ width: 350 }}><ChipGroup options={['Wind', 'Temp', 'Rain 1 h', '⚡ 60 min']} selected="Wind" /></div>
```
