# 03 — Product and visual design

## 1. Principles
1. **One question per screen.** Home answers "what is it like and can I go out?".
   Everything else is one tap deeper.
2. **Numbers over icons.** Large, calm typography; icons only where they carry meaning
   (wind arrow, sky state).
3. **Colour means something.** A neutral, near-monochrome UI. The only accent colour is
   the *condition* (poor → good → epic) or a warning level. Nothing is coloured for
   decoration.
4. **Show the source and age.** "Meteocat · Castelldefels station · 12 min ago". Trust
   comes from honesty, and it is required attribution.
5. **Progressive disclosure.** Score → reason → detailed chart → raw data.
6. **Dark first,** with a light theme.

## 2. Visual language (v2: warm, natural, pastel)
Mockups: `design/mockups-v2.html` (+ `daily.js`), rendered to `design/mockups-v2.png`.

- **Type:** DM Sans, tabular figures. Hero 64 Light, title 22–24 Semibold, body 15/13,
  label 11 uppercase-spaced.
- **Neutrals (warm espresso):** bg `#15130F`, surface `#1E1B17`, surface-2 `#27231E`,
  line `#36312A`, text `#F1EBE2` / `#B0A596` / `#7E7468`.
- **Weather accents (pastel, one meaning each):** wind `#62C7A2` sage-teal · heat
  `#F39A70` apricot · water (rain, waves) `#8AAEF2` sea blue · sun `#EAC160` honey ·
  storm and lightning `#BA9BF1` lavender · snow and cold `#D7E3F0` frost · cloud `#A79E92`.
  Checked with the dataviz validator on `#1E1B17`: chroma, colour-blind and normal-vision
  separation and contrast all pass. The lightness band check fails on purpose, because
  pastels are lighter than the mid-tone band. Charts are direct-labelled, so the
  wind/heat pair (deutan ΔE 8.0) has secondary encoding.
- **Condition rating (ordinal ramp, sage):** `#4E5246 #667A5A #86A276 #A9C895 #D6EBC3`;
  always paired with the dot count.
- **Wind speed on map (ordinal ramp, teal):** `#35584C #3F7D68 #4FA184 #62C7A2 #B0EBD5`.
- **Warnings (strong, reserved):** yellow `#F4D266` · orange `#EF8440` · red `#CF3A78`;
  always with a triangle icon and the level name.
- **Shape and motion:** 20 dp cards, no shadows, 1 dp hairlines, 8 dp grid; 200 ms
  fades.

## 3. Signature visual components
| Component | Shows | Used in |
|---|---|---|
| **Wind band** | 24–72 h line of mean wind with a translucent band up to the gusts; small direction arrows every 3 h; the user's rideable range shaded | wing, bike, home |
| **Go-window bar** | a horizontal day strip coloured by hourly score; the best window labelled "16–19 h" | every activity |
| **Wave bars** | height bars, period as a number on top, direction tick | surf |
| **Compass dial** | live wind direction against the spot's shoreline (onshore / side / offshore sectors drawn) | wing, surf |
| **Sparkline tiles** | value + 24 h sparkline (temp, pressure trend, SST) | details |
| **Unusualness pill** | "warmest 3 Nov in 12 years" from XEMA statistics | home, history |

## 4. Information architecture
Bottom navigation with 4 items: **Today · Activities · Map · Spots**. History is reached
from any station or spot.

### Today
```
 Barcelona · now                                ⚙
 ─────────────────────────────────────────────
 18°                  Mostly sunny
 feels 17° · wind SW 14 kn, gusts 21
 ─────────────────────────────────────────────
 [ amber banner only when a warning is active ]
 ─────────────────────────────────────────────
 Wing   ●●●●○  16–19 h  side-shore 15–19 kn
 Surf   ●○○○○  flat, 0.3 m
 Bike   ●●●●●  all day, dry roads
 Run    ●●●●○  before 11 h (UV 6 later)
 Hike   ●●○○○  storms likely after 15 h
 ─────────────────────────────────────────────
 next 24 h   ▁▂▃▅▆▆▅▃  temp + rain dots
 ─────────────────────────────────────────────
 7 days  (compact rows: day · symbol · min—max · rain %)
```

### Activity detail (wing foiling example)
- Hero: score + "Best: Thu 16–19 h at Castelldefels".
- Wind band (72 h) with the user's range (e.g. 14–24 kn for a 5 m wing) shaded.
- Compass dial with the live station reading.
- Facts row: gust factor 1.3 · water 19° → 3/2 wetsuit · sunset 17:41 · waves 0.4 m.
- "Why" list: three short bullet reasons.
- Spot switcher (horizontal chips).

### Map
MapLibre, minimal greyscale style. Layer toggle: wind (arrows coloured by speed) ·
temperature · rain last hour · lightning (last 60 min, dots fading with age) ·
warnings (counties shaded). Tap a station → bottom sheet with sparklines and
"Open history".

### Spots
User-defined places that link a municipality (for forecasts), the nearest or chosen
station(s), an optional beach / summit slug, and an activity profile. Each card shows
live wind/waves and today's best window.

### History and analysis (per station)
Calendar heat-map (e.g. windy days per month), records, monthly climatology vs this
year, "best wing months at this spot" computed from our archive + XEMA statistics.

### Home-screen widgets (home_widget: native layouts fed from Flutter)
- Small: live wind at the main spot (number + arrow + gust).
- Medium: today's scores for 3 chosen activities.

## 4b. Daily planners (one per sport)
Day tabs (3 days hourly + 5-day outlook, each tab with a rating tick) → verdict card
(rating, best window, why, confidence) → **hour-by-hour chart**: one SVG where every
variable is a row on the same hour columns, with night shaded and the best window
framed → planning cards:
- **Wing:** gear by rider weight, forecast vs station (spot bias), pressure trend,
  water, sunset, lightning, pre-warnings.
- **Surf:** swell window compass, buoy 24 h trend, warning, water, wetsuit.
- **Bike:** ride-length picker → best departure, wind along the saved route
  (tail/cross/head), roads and trails (rain observed, ET₀, soil moisture), what to wear.
- **Run:** run-length picker, feels-like vs comfort band, humidity, UV and irradiance
  (sun vs shade), body cards.
- **Hike:** plan timeline with turn-back limit, summit chart (storm %, wind, temp,
  precipitation, snow level), temperature by altitude, snow depth, county lightning,
  daylight.

Each planner ends with its data sources. The data coverage table in the mockups maps
every endpoint to where it is shown.

## 5. Activity scoring engine (backend, transparent and configurable)
Each activity = a set of **factors** that map to 0–1, a hard-stop list, and a weighted
geometric mean → 0–100 → five dots. Every factor reports a human reason string.

| Activity | Main factors (defaults, user-tunable) | Hard stops |
|---|---|---|
| **Wing foil** | mean wind in the user's range (default 14–25 kn); gust factor ≤ 1.35; direction vs the spot's shoreline (side/side-on best, **offshore = stop**); waves < 1 m for flatwater spots; daylight | lightning ≤ 20 km in the last 30 min, wind/sea warning, offshore wind |
| **Surf** | significant wave height 0.6–2 m; **period ≥ 7 s** (buoy or Open-Meteo marine); swell direction vs the beach's exposure window; wind offshore/light; water temp → wetsuit | sea-state warning (orange+), lightning |
| **Bike** | rain probability + rain in the last 3 h (wet roads); wind < 25 km/h and gusts; temp 8–28 °C; for a saved route (GPX): head/tailwind share | ice (temp < 1 °C + wet), red warnings |
| **Run** | apparent temperature / heat index from temp + RH; UV; rain; best cool window | heat warning, lightning |
| **Hike** | summit/hut forecast; afternoon thunderstorm risk (symbols + XDDE); wind on peaks; snow depth / snow level; daylight hours | lightning, snow/avalanche-type warnings |

Gear helper derived from water temperature: ≥ 22 °C shorty / boardshort, 18–22 3/2,
15–18 4/3, < 15 5/4 + boots.

## 6. Language
Catalan, Spanish and English UI (Meteocat texts are Catalan). Units: kn / km/h / m/s
selectable per activity (wing defaults to knots).
