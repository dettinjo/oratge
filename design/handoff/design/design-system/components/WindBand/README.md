WindBand from @oratge/ui. Use via `window.OratgeUI.WindBand` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Multi-day wind chart: sage-teal mean line, translucent gust band, hatched personal range, night shading, best window. Wing foil signature visual.

## Props

```ts
interface WindBandProps {
  /** Mean wind per hour (kn), any length (e.g. 72 for 3 days). */
  mean: number[];
  /** Gusts per hour (kn), same length. */
  gust: number[];
  /** Direction FROM per hour, degrees — arrows drawn every 6 h. */
  directions?: number[];
  /** The rider's usable range, hatched, e.g. [14, 24]. */
  range?: [number, number];
  /** Day labels, one per 24 values. */
  days?: string[];
  /** [startIndex, endIndex) hour ranges to shade as night. */
  night?: [number, number][];
  /** [startIndex, endIndex] to frame as the best window. */
  best?: [number, number];
  /** Axis max in kn (default 35). */
  max?: number;
  width?: number;
  height?: number;
}
```

## Examples

### ThreeDays

```jsx
() => <WindBand mean={mean} gust={gust} directions={dirs} range={[14, 24]} days={['Mon', 'Tue', 'Wed']} night={[[0, 7.5], [17.6, 31.5], [41.6, 55.5], [65.6, 71]]} best={[37, 41]} />
```

### OneDayNoRange

```jsx
() => <WindBand mean={mean.slice(24, 48)} gust={gust.slice(24, 48)} directions={dirs.slice(24, 48)} days={['Tue']} night={[[0, 7.5], [17.6, 23]]} />
```
