# Oratge design system — how to build with it

Oratge is a minimalist weather app for Catalonia (Meteocat data) for wing foiling, surfing, biking, running and hiking. The look: a warm, almost monochrome dark UI; pastel colour appears **only** where it means something.

## Setup
Wrap every screen in `OratgeRoot`. It sets the warm dark background (`--og-bg` #15130F), DM Sans with tabular figures and the base text colour. Without it, text renders in browser defaults on white. Phone screens are 390 px wide.

```jsx
<OratgeRoot padded width={390}>
  <CurrentConditions place="Barcelona" source="Meteocat · Zoo station · 8 min ago" sky="partly" temp={18} summary="Mostly sunny" feels={17} min={11} max={21} wind="SW 14 kn · gusts 21" />
  <SectionLabel>Today for you</SectionLabel>
  <ActivityRow sport="wing" rating={4} window="13–17 h" reason="side-on SW 16–19 kn" />
  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 12 }}>
    <FactTile label="Water" value="18.6°" sub="3/2 suit" /><FactTile label="Sunset" value="17:35" />
  </div>
  <BottomNav active="Today" />
</OratgeRoot>
```

## Colour language (never break it)
- One meaning per hue: wind `--og-wind` sage-teal · heat/temperature `--og-heat` apricot · water (rain, waves) `--og-water` sea blue · sun/UV `--og-sun` honey · storm/lightning `--og-storm` lavender · snow/cold `--og-snow` frost.
- Ratings 1–5 use the sage ramp `--og-r1`…`--og-r5`, always via `RatingDots`, `RatingStrip` or the `rating` row of `HourChart` (dot count + colour).
- Warning colours `--og-warn-yellow|orange|red` are reserved for `WarningBanner` and map warning areas.
- Text is always neutral: `--og-text`, `--og-text-2`, `--og-text-3`. Never colour body text with an accent.
- Surfaces: `--og-surface` (cards), `--og-surface-2` (nested), hairlines `--og-line`; radius `--og-radius` 20px; spacing `--og-space-1…6` (4–24px).
- Tokens are also exported in JS as `colors`, `ratingRamp`, `windRamp` and `accentColor(accent)` for custom SVG.

## Styling idiom
Components are styled internally. For your own layout glue, use inline styles with the `var(--og-*)` tokens, or the shipped helper classes `og-card`, `og-label`, `og-muted`, `og-faint`, `og-row`, `og-grow`. Read `styles.css` for the full token list.

## Composition patterns
- **Daily planner** (one per sport): `DayTabs` → `VerdictCard` → `SectionLabel "Hour by hour"` + `Card` with `HourChart` → planning cards (`FactTile` grids, `TrendLine`, `RouteWind`, `SwellWindow`, `AltitudeProfile`) → `DataSources`.
- **HourChart** rows share hour columns: `icons`, `rating`, `line` (with `band` for gusts, `range` for the user's range, `companion` for feels-like), `bars`, `arrows` (with `shore` relation for wing/surf), `numbers`, `category` (e.g. wet/damp/dry roads). Give it `best` and `sunrise`/`sunset`.
- Charts never mix two units on one axis; use separate rows or charts.
- Every planner ends with `DataSources`. Live values state their source and age.
