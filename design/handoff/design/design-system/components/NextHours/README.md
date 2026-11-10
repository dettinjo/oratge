NextHours from @oratge/ui. Use via `window.OratgeUI.NextHours` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Today's next-24-h strip: sky icons, apricot temperature line with min/max labels, blue rain-probability bars underneath.

## Props

```ts
interface NextHoursProps {
  /** Hourly temperature (°C), usually 24 values. */
  temps: number[];
  /** Hourly rain probability (%), same length. Drawn as a separate strip — never on the temperature axis. */
  rain: number[];
  /** Hourly sky, same length (icons every 3 h). */
  sky: WeatherKind[];
  /** Hour of the first value, e.g. 10. */
  startHour: number;
  width?: number;
}
```

## Examples

### Next24

```jsx
() => (
  <NextHours startHour={10} temps={[17, 16, 15, 14, 14, 13, 13, 14, 16, 18, 19, 20, 21, 21, 20, 19, 18, 17, 16, 15, 15, 14, 14, 13]}
    rain={[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 10, 20, 45, 60, 40, 20, 10, 5, 0, 0, 0, 0]}
    sky={['partly', 'partly', 'cloud', 'cloud', 'night', 'night', 'night', 'night', 'night', 'night', 'night', 'night', 'partly', 'cloud', 'storm', 'rain', 'rain', 'cloud', 'cloud', 'sun', 'sun', 'sun', 'partly', 'partly']} />
)
```
