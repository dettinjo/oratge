# Oratge design system — how to build with it

Oratge is a minimalist weather app for Catalonia (Meteocat data) for wing foiling, surfing, biking, running and hiking. The look: a warm, almost monochrome UI in a dark and a light theme; colour appears **only** where it means something.

## Setup
Wrap every screen in `OratgeRoot`. It sets the theme background (`--og-bg`: #150F0B dark, #F8F2EE light), DM Sans with tabular figures and the base text colour. Without it, text renders in browser defaults on white. Phone screens are 390 px wide.

```jsx
<OratgeRoot padded width={390}>
  <CurrentConditions place="Barcelona" source="Meteocat · el Raval station · 8 min ago" sky="partly" temp={18} summary="Mostly sunny" feels={17} min={11} max={21} wind="SW 14 kn · gusts 21" />
  <SectionLabel>Today for you</SectionLabel>
  <ActivityRow sport="wing" rating={4} window="13–17 h" reason="side-on SW 16–19 kn" />
  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 12 }}>
    <FactTile label="Water" value="18.6°" sub="3/2 suit" /><FactTile label="Sunset" value="17:35" />
  </div>
  <BottomNav active="Today" />
</OratgeRoot>
```

## Colour language (never break it)
- Two themes: set `data-theme="dark"` (default) or `data-theme="light"` on `<html>` or any wrapper. The neutrals switch (`--og-bg`, `--og-surface`, `--og-surface-2`, `--og-line`, `--og-night`, the text greys) and the accents step lighter in dark; background and cards come from one tint, cards one step lighter.
- One meaning per hue, the same hue in both themes (dark uses a lighter step of it for contrast): wind `--og-wind` green · heat/temperature `--og-heat` orange · water (rain, waves) `--og-water` blue · sun/UV `--og-sun` amber · storm/lightning `--og-storm` violet · snow/cold `--og-snow` slate. They hold at least 6.5:1 on dark surfaces and 3.2:1 on light ones: use them for lines, marks, icons and large values, never small text.
- Ratings 1–5 use the green ramp `--og-r1`…`--og-r5` (brighter with the rating in dark, more saturated in light), always via `RatingDots`, `RatingStrip` or the `rating` row of `HourChart` (dot count + colour).
- Warning colours `--og-warn-yellow|orange|red` are reserved for `WarningBanner` and map warning areas.
- Colour explains the data: give a value its accent only when it IS that quantity (wind speed `wind`, swell `water`, summit temperature `snow`, storm risk `storm`); labels, times and advice stay neutral.
- Answer first, evidence second, method last: verdict → key numbers → hour-by-hour chart (with a one-line takeaway above it) → details. Model and ensemble analysis sits in a collapsed “How this forecast was made” section.
- Nothing smaller than 12px; secondary text uses `--og-text-2`, `--og-text-3` only for disabled or decorative text.
- Lead every screen with ONE strip of 2–4 key numbers, `FactTile size="lg"` (36px), holding what decides the plan; secondary facts use regular `FactTile`s (24px).
- Text is always neutral: `--og-text`, `--og-text-2`, `--og-text-3`. Never colour body text with an accent.
- Surfaces: `--og-surface` (cards), `--og-surface-2` (nested), hairlines `--og-line`; radius `--og-radius` 20px; spacing `--og-space-1…6` (4–24px).
- Tokens are also exported in JS as `colors`, `ratingRamp`, `windRamp` and `accentColor(accent)` for custom SVG; their values are `var(--og-*)` references, so they follow the theme.

## Styling idiom
Components are styled internally. For your own layout glue, use inline styles with the `var(--og-*)` tokens, or the shipped helper classes `og-card`, `og-label`, `og-muted`, `og-faint`, `og-row`, `og-grow`. Read `tokens.json` for the full token list.

## Composition patterns
- **Daily planner** (one per sport): `DayTabs` → `VerdictCard` → `SectionLabel "Hour by hour"` + `Card` with `HourChart` → planning cards (`FactTile` grids, `TrendLine`, `RouteWind`, `SwellWindow`, `AltitudeProfile`) → `DataSources`.
- **HourChart** rows share hour columns: `icons`, `rating`, `line` (with `band` for gusts, `range` for the user's range, `companion` for feels-like), `bars`, `arrows` (with `shore` relation for wing/surf), `numbers`, `category` (e.g. wet/damp/dry roads). Give it `best` and `sunrise`/`sunset`.
- Charts never mix two units on one axis; use separate rows or charts.
- Every planner ends with `DataSources`. Live values state their source and age.

# OratgeUI (@oratge/ui@0.1.0)

This design system is the published @oratge/ui React library, bundled as a single
browser global. All 28 components are the real upstream code.

## Where things are

- `components/bundle.js` — the whole-DS bundle; loads every component to `window.OratgeUI`. First line is a `/* @ds-bundle: … */` metadata header.
- `styles.css` — the single stylesheet entry: it `@import`s the tokens, fonts, and component styles (`_ds_bundle.css`). Link this one file.
- `components/<Name>/README.md` (example JSX + variants), `components/<Name>/<Name>.d.ts` (types), `components/<Name>/preview.html` (variant grid).
- `tokens.json` — the tokens; `tokens.css` compiles them to CSS custom properties, names verbatim from upstream.
- `fonts/` — `@font-face` files + `fonts.css` (when the package ships fonts).

For a specific component, `read_file("components/<Name>/README.md")`.

## Loading

Add these two lines to your page once (React must be on the page first):

```html
<link rel="stylesheet" href="styles.css">
<script src="components/bundle.js"></script>
```

Components are then available at `window.OratgeUI.*`. Mount into a dedicated child node (e.g. `<div id="ds-root">`), not the host page's own React root, so the two trees don't collide:

```jsx
const { ActivityRow } = window.OratgeUI;
ReactDOM.createRoot(document.getElementById('ds-root')).render(<ActivityRow />);
```

Wrap the tree in the provider — most components read theme/i18n from context:

```jsx
<OratgeRoot padded={true}>{children}</OratgeRoot>
```

## Tokens

33 CSS custom properties from @oratge/ui. Names are
preserved verbatim from upstream. They are declared in `tokens.json` and compiled to `tokens.css`; `components/bundle.css` keeps only `--og-font` and the component styles.

- **color** (4): `--og-surface`, `--og-surface-2`, `--og-text-2`, …
- **spacing** (6): `--og-space-1`, `--og-space-2`, `--og-space-3`, …
- **typography** (1): `--og-font`
- **radius** (2): `--og-radius`, `--og-radius-sm`
- **other** (20): `--og-bg`, `--og-line`, `--og-night`, …

## Components

### general
- `ActivityRow` — One row of the Today screen's Today for you list. Stack 35 in a column rows draw their own dividers.
- `BottomNav` — App navigation with the four top-level sections. Sits at the bottom of every phone screen.
- `Card` — Rounded surface (20px radius, no shadow) that groups related content.
- `ChipGroup` — Single-select pill chips: layer toggles, ride/run length pickers.
- `CurrentConditions` — Today-screen hero: place, source and age, big temperature, sky, feels-like, range and wind.
- `DataSources` — Footnote listing the data behind a screen (Meteocat endpoints, stations, gap fillers). Required at the end of every planner  attribution and
- `DayTabs` — Day picker for daily planners. Each tab carries a rating tick so the best day is visible at a glance.
- `FactTile` — Single key fact. Lay out in 2- or 4-column grids.
- `ForecastDayRow` — One line of the 7-day list: day, sky, rain chance, minmax on a shared temperature scale.
- `OratgeRoot` — Root wrapper for every Oratge screen: warm dark background, DM Sans, tabular figures. Wrap every design in it.
- `RatingDots` — Five dots on the sage rating ramp. The filled count AND the colour carry the rating, so it never relies on colour alone.
- `RatingStrip` — Compact horizontal bar of rating cells  how good is each hour. Used on spot cards and the go-window.
- `SectionLabel` — Small uppercase section heading, e.g. Hour by hour or What to wear.
- `SpotCard` — Saved place with live wind and today's rating strip. Stack in a column on the Spots screen.
- `VerdictCard` — Top-of-planner verdict: rating, the best window and the reasoning. One per daily planner.
- `WarningBanner` — Official Meteocat warning. Warning colours are reserved for this component and the map overlay always shown with the triangle icon and level
- `WeatherIcon` — Weather glyph with the accent colour that matches its meaning (sun  honey, rain/waves  sea blue, storm  lavender, wind  sage-teal, heat  apr

### charts
- `AltitudeProfile` — Hike chart: temperature by altitude (valley  hut  summit) with the 0 C line and snow level.
- `CalendarHeatmap` — History heatmap (e.g. rideable hours per day) on the sage rating ramp.
- `HourChart` — The planner meteogram: every variable as one row on shared hour columns, with night shading and the best window framed.
- `MonthBars` — Climatology bars per month, e.g. rideable days per month at a station.
- `NextHours` — Today's next-24-h strip: sky icons, apricot temperature line with min/max labels, blue rain-probability bars underneath.
- `RouteWind` — Bike route coloured by wind effect for the chosen start time: tailwind sage-teal, crosswind neutral, headwind apricot.
- `SwellWindow` — Surf compass: the sea-facing window shaded sea blue, the swell arrow travelling towards the beach. Shows at a glance whether the swell can r
- `TrendLine` — Small single-measure trend: live wind sparkline, pressure trend, forecast-vs-measured, buoy history. One axis only  never mix units.
- `WaveBars` — Surf chart: sea-blue wave-height bars with the period on top and wind arrows underneath.
- `WindBand` — Multi-day wind chart: sage-teal mean line, translucent gust band, hatched personal range, night shading, best window. Wing foil signature vi
- `WindCompass` — Live wind against the shoreline: offshore half shaded neutral, sea-side half tinted sage-teal, dashed shoreline, arrow pointing downwind.
