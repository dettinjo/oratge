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

## 2. Visual language
- **Type:** one family, e.g. *Inter* or *IBM Plex Sans* (tabular figures for numbers).
  Display 56 sp for the hero value, Title 22, Body 15, Label 12 uppercase-spaced for
  units.
- **Palette (dark):** background `#0E1012`, surface `#16191C`, text `#E8EAED` /
  secondary `#9AA0A6`, lines `#2A2E33`.
  Condition scale (one hue family, colour-blind safe): `#5B6670` poor · `#4F8FBF` ok ·
  `#3FB8A4` good · `#E9C46A` epic. Warnings: amber `#F2A541`, red `#E5534B`.
- **Shape:** 20 dp cards, no shadows, 1 dp hairlines; 8 dp grid; generous whitespace.
- **Motion:** a 200 ms fade or slide; the wind arrow eases to its new direction; no
  bouncing.

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

### Widgets (Glance)
- Small: live wind at the main spot (number + arrow + gust).
- Medium: today's scores for 3 chosen activities.

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
