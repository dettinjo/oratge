WindCompass from @oratge/ui. Use via `window.OratgeUI.WindCompass` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Live wind against the shoreline: offshore half shaded neutral, sea-side half tinted sage-teal, dashed shoreline, arrow pointing downwind.

## Props

```ts
interface WindCompassProps {
  /** Direction the wind comes FROM, degrees. */
  from?: number;
  /** Same as `from`; use this where `from` is a reserved attribute (e.g. a Design canvas). */
  direction?: number;
  /** Mean speed (kn), shown in the centre. */
  speed: number;
  /** Direction the beach faces (towards the sea), degrees. Sectors: from the sea = rideable, from land = offshore. */
  shoreFacing: number;
  /** Caption under the dial, e.g. "live · side-shore". */
  caption?: string;
  size?: number;
}
```

## Examples

### SideOnshore

```jsx
() => <WindCompass from={225} speed={14} shoreFacing={170} caption="live · side-shore" />
```

### Offshore

```jsx
() => <WindCompass from={330} speed={9} shoreFacing={170} caption="live · offshore — stay ashore" />
```
