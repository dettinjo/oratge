CurrentConditions from @oratge/ui. Use via `window.OratgeUI.CurrentConditions` (bundle loaded from `components/bundle.js`). Wrap the tree in `<OratgeRoot>` (full provider chain in README.md — components read theme/i18n from that context).

Today-screen hero: place, source and age, big temperature, sky, feels-like, range and wind.

## Props

```ts
interface CurrentConditionsProps {
  place: string;
  /** Source line, e.g. "Meteocat · Zoo station · 8 min ago". */
  source: string;
  sky: "sun" | "partly" | "cloud" | "rain" | "storm" | "bolt" | "wind" | "wave" | "heat" | "snow" | "uv" | "night" | "fog";
  /** Current temperature °C. */
  temp: number;
  /** e.g. "Mostly sunny". */
  summary: string;
  feels: number;
  min: number;
  max: number;
  /** e.g. "SW 14 kn · gusts 21". */
  wind: string;
}
```

## Examples

### Barcelona

```jsx
() => <div style={{ width: 350 }}><CurrentConditions place="Barcelona" source="Meteocat · Zoo station · 8 min ago" sky="partly" temp={18} summary="Mostly sunny" feels={17} min={11} max={21} wind="SW 14 kn · gusts 21" /></div>
```

### RainyMountain

```jsx
() => <div style={{ width: 350 }}><CurrentConditions place="Berga" source="Meteocat · Berga station · 12 min ago" sky="rain" temp={7} summary="Showers" feels={4} min={5} max={11} wind="N 9 kn · gusts 17" /></div>
```
