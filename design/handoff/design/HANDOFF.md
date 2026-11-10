# Oratge — implementation handoff (Flutter)

Oratge is a weather app for Catalonia (Meteocat data) that rates conditions for wing foiling, surfing, biking, running and hiking. This folder is everything needed to build it in Flutter. Read this file first, then follow the build order at the end.

## What is in this folder

| Path | What it is | How to use it |
|---|---|---|
| `design-system/README.md` | The brand book: colour language, hierarchy and readability rules | Rules the app must follow. Read before writing UI. |
| `design-system/tokens.json` | All tokens: colours (dark + light), type styles, spacing, radii | Source of truth for values. |
| `flutter/oratge_tokens.dart` | `tokens.json` generated as Dart: `OratgeColors` (ThemeExtension, dark + light), `OgText`, `OgSpace`, `OgRadius`, `oratgeTheme()` | Drop into `lib/theme/`. Never hard-code a colour or size elsewhere. |
| `design-system/components/<Name>/` | Per component: `README.md` (usage + examples), `<Name>.d.ts` (props), `preview.html` (open in a browser to see every variant) | The contract for each Flutter widget. |
| `design-system/components/index.d.ts` | Every component's props in one file | Quick reference. |
| `design-system/react-source/` | The original React (`.jsx`) implementation and compiled bundle | Read for exact drawing logic (chart geometry, icon paths, scales). Port, don't run. |
| `screens/outline/*.json` | Each screen (dark, per device) as a tree: which component, with which props, in which order, plus headings, links and form inputs | The screen spec. Data values are sample data. |
| `screens/artboards/*.dc.html` | The original design artboards (all devices, dark + light) and `index.json` | Visual reference. They only render inside the design canvas; read them as markup. `Main.dc.html` = phone Today (dark). |
| `logic/planner-logic.json` | Per sport: rating factors with weights and scores, model agreement, station check, "Tuned to you" rules, chart takeaways | The rules behind the planner screens. |
| `CLAUDE.md` | Starter project instructions for Claude Code | Copy to the root of the Flutter repo. |

## Screens

Devices: phone (390 wide, bottom nav), tablet (834, left rail), desktop (fluid, sidebar). Every screen exists in dark and light.

| Screen | Outline file | Contents (top to bottom on phone) |
|---|---|---|
| Today | `phone-today.json` | Best today card, pre-warning, current conditions, key numbers (Right now), next 24 h, today per sport, 7 days, forecast confidence, daylight, sources |
| Activities | `phone-activities.json` | Activity rows (link to planners), day tabs, rideable-hours heatmap, rideable days per month |
| Planner × 5 (wing, surf, bike, run, hike) | `phone-<sport>.json` | Day tabs, verdict, key numbers, hour-by-hour chart with takeaway, Tuned to you, sport visuals, plan tiles, 3-day outlook, "How this forecast was made" (collapsed: models, ensemble, rating breakdown, station check), sources |
| Map | `phone-map.json` | Layer chips, map with spot pins coloured by rating, official warnings |
| Spots / Spot detail | `phone-spots.json`, `phone-spot.json` | Saved spots; live wind, forecast vs measured, climatology |
| Profile | `phone-profile.json` | Header with setup progress, You, Appearance (Light/Dark/System), Sports and gear, App |
| Setup flow (10 steps) | `phone-setup-1.json` … `phone-setup-10.json` | You and units + appearance, body and pace, sports, wing, surf, bike, run, hike, alerts and privacy, done |

Tablet and desktop use the same blocks re-flowed into two columns; compare `tablet-*.json` / `desktop-*.json` with the phone version.

## Flutter architecture (recommended)

- **Theme:** `MaterialApp(theme: oratgeTheme(Brightness.light), darkTheme: oratgeTheme(Brightness.dark), themeMode: <user setting>)`. The Appearance setting maps to `ThemeMode.light / dark / system`; persist it (e.g. `shared_preferences`). Read colours via `context.og.wind`, never `Colors.*`.
- **Fonts:** DM Sans 300/400/500/600/700. Flutter cannot use the `.woff2` files from the web design; add the DM Sans TTFs (Google Fonts, OFL) under `assets/fonts/` with family name `DMSans` in `pubspec.yaml`. Always use tabular figures for numbers (already set in `OgText`).
- **Navigation:** `go_router` with a shell route for the 4 tabs (Today, Activities, Map, Spots). Phone: `NavigationBar` styled like `BottomNav`. Tablet: `NavigationRail`. Desktop (≥ 1024 px): sidebar with the Appearance switch. Profile opens from the top-right avatar button (phone) or the last nav item (tablet/desktop). The setup flow is a separate full-screen route with its own progress header.
- **Responsive breakpoints:** < 600 phone layout, 600–1023 tablet, ≥ 1024 desktop. Use `LayoutBuilder`; the outlines show which blocks sit side by side.
- **Widgets:** one Flutter widget per design-system component, same name prefixed `Og` (`OgFactTile`, `OgHourChart`, …), props from the `.d.ts`. Charts (`HourChart`, `WindBand`, `WaveBars`, `TrendLine`, `MonthBars`, `CalendarHeatmap`, `AltitudeProfile`, `RouteWind`, `SwellWindow`, `WindCompass`, `NextHours`) are `CustomPainter`s ported from `react-source/` — their geometry is in the JSX. Weather glyphs (`WeatherIcon`) are SVG paths in the bundle; port to `CustomPainter` or export them as SVGs for `flutter_svg`.
- **State:** a profile/settings model (setup flow fields, see `screens/outline/phone-setup-*.json` inputs) persisted locally; forecasts behind a repository interface with a sample-data implementation first (all values in the outlines are sample data).
- **Data:** the app talks only to the Oratge backend, never to Meteocat or Open-Meteo directly (API key secrecy and the Meteocat quota). Start with the sample data; wire the API after the UI is done. Which source feeds which field is in the next section.

## Data sources per screen element

Meteocat stays the primary, attributed source. Open-Meteo (free for non-commercial use) fills only the fields Meteocat does not publish, plus the analysis sections. Full analysis: `docs/04-design-data-fit.md` in the repo.

| Element | Source |
|---|---|
| Live readings, gusts (last 30 min), pressure, rain observed, sea temperature, buoys | Meteocat XEMA stations (30-min resolution) |
| Today, 7 days, hourly temp/feels/rain/wind/sky, UV | Meteocat municipal hourly + daily forecast, UV forecast |
| Wing/surf hourly wind, wave height + direction, water temperature | Meteocat beach forecast |
| Summit/hut forecast (hike) | Meteocat Pyrenees summit + refugi forecast |
| Warnings, pre-warnings, lightning | Meteocat warnings (SMP), XDDE |
| **Gust forecast**, **wave period / swell**, **hourly storm risk**, **snow level**, hourly beyond day 3 | Open-Meteo (forecast, marine) |
| Model agreement | "Meteocat" = Meteocat's finished forecast (no raw WRF/SWAN in the API); other rows = Open-Meteo models (AROME, ARPEGE, ICON-EU, ECMWF IFS, GFS; waves: MFWAM, DWD EWAM, ECMWF WAM, GFS wave) |
| Ensemble, forecast confidence | Open-Meteo ensemble, ECMWF ENS 51 members |
| Station check, rideable-hours history | Oratge backend archive (forecasts + XEMA observations, built up from setup day) |
| Climb time, ascent | the spot's GPX route (elevation), not weather data |
| Sunrise, sunset, last light | computed astronomically |

Station names are never hard-coded: they come from XEMA station metadata (sample data uses el Raval, Viladecans, Gisclareny, Guardiola de Berguedà, which exist). Alerts are evaluated on the server, so only alert thresholds leave the device.

## Rules that must survive implementation

1. Colour explains the data: wind = `wind`, water/rain/waves = `water`, temperature = `heat`, UV/sun = `sun`, storm/lightning = `storm`, cold/snow = `snow`. Labels, times and advice stay neutral. Ratings 1–5 use `r1…r5` and always show the dot count too.
2. Hierarchy: answer first (verdict, key numbers 36 px), evidence second (chart with a one-line takeaway above it), method last (collapsed "How this forecast was made").
3. Nothing below 12 px (charts included); secondary text uses `text2`; `text3` only for decorative text.
4. Accents are for lines, marks, icons and large values, never small text. Dark theme uses the lighter accent step (already in `OratgeColors.dark`).
5. Touch targets ≥ 44 × 44; every chart gets a `Semantics` label equal to its takeaway sentence.

## Build order and acceptance checks

1. **Theme** — `oratge_tokens.dart`, fonts, `ThemeMode` switch. ✔ A test screen toggles light/dark/system and every token renders.
2. **Primitives** — `OgRoot`, `OgCard`, `OgSectionLabel`, `OgFactTile` (md + lg), `OgRatingDots`, `OgChipGroup`, `OgDataSources`, `OgWeatherIcon`. ✔ A widgetbook/gallery page matches each `preview.html`.
3. **Rows and cards** — `OgActivityRow`, `OgForecastDayRow`, `OgVerdictCard`, `OgWarningBanner`, `OgSpotCard`, `OgDayTabs`, `OgCurrentConditions`, `OgBottomNav`.
4. **Charts** — `OgHourChart` first (used by all planners), then the rest. ✔ Same props as the outlines produce the same picture as the artboards.
5. **Today + Wing planner end to end** with sample data, phone layout. ✔ Matches `Main.dc.html` / `phone-wing.dc.html` in both themes.
6. Remaining planners, Activities, Map, Spots, Spot detail.
7. Profile, setup flow (10 steps, Back / Continue / Skip, progress), Appearance setting.
8. Tablet and desktop layouts.
9. Meteocat data layer and the rating logic from `logic/planner-logic.json`.
