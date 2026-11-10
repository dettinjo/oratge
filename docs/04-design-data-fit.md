# 04 — Does the Claude Design handoff fit the Meteocat data?

Reviewed 2026-11-09: `oratge-design-handoff.zip` (HANDOFF.md, planner-logic.json, 39 phone/tablet/desktop
outlines, setup flow). Compared against 01-api-analysis.md. Station names were checked against a
third-party list of 189 XEMA stations (snowy.es). **Without an API key, everything marked ⚠ is
unverified.**

Legend: ✅ Meteocat API directly · 🔧 computed by our backend from Meteocat (+ profile) ·
🌍 needs another source (Open-Meteo or similar) · ❌ no realistic source → change the design.

## 1. Verdict

The **core of the design fits**: Today, warnings, live readings, the hour-by-hour charts for
wind/temperature/rain/UV/waves, the beach and summit planners, the station history and the map all map
onto Meteocat endpoints. Three areas don't:

1. **"How this forecast was made"** (model agreement across 6 named models, 67-member ensemble,
   forecast-confidence card on Today) is not Meteocat data at all. The API only returns Meteocat's
   finished forecasts, not raw model runs (no WRF, no SWAN). Part of it can come from Open-Meteo, not
   all of it.
2. **Several forecast fields** are missing from Meteocat forecasts: gusts, wave period / swell vs wind
   sea, hourly storm probability, snow level ⚠, and anything hourly beyond about 3 days.
3. **The free forecast quota** (about 100 calls a month ⚠) can't feed five planners. The design needs
   roughly 10–15 forecast calls a day.

## 2. Screen by screen

### Today
| Element | Source | Status |
|---|---|---|
| Current conditions, "Right now" wind/gusts | XEMA `ultimes` (30, 31, 50, 32, 33) | ✅ |
| Water 18.6° | XEMA buoy 97 or beach forecast `temperaturaAigua` | ✅ |
| UV now / max at 13 h | `pronostic/uvi/{town}` | ✅ |
| Next 24 h temp + rain | `municipalHoraria` | ✅ (hourly rain **probability** ⚠, may only be the amount) |
| Today per sport, Best today | ratings from our engine | 🔧 |
| 7 days | `pronostic/municipal` | ✅ |
| Pre-warning | `smp/episodis-oberts/preavisos` | ✅ |
| "No rain for the next 2 hours" | radar nowcast | ❌ not in the API → derive from the hourly forecast and say "forecast", or drop |
| Forecast confidence (67 ensemble members) | ensemble | 🌍 Open-Meteo Ensemble (ECMWF IFS ENS 51 members ✅; AROME-EPS 16 ⚠ probably not available) |
| Daylight, last light | astronomical calculation | 🔧 |

### Wing foil planner
| Element | Source | Status |
|---|---|---|
| Wind line, direction vs shore, waves, air, rain | beach forecast (hourly wind, waves) + `municipalHoraria` | ✅ |
| Gust band / gust row / "gusts ≤ 24" | **not in Meteocat forecasts** ⚠ | 🌍 Open-Meteo `wind_gusts_10m` |
| Live compass + 4 h trend | XEMA 30/31/50 | ✅ |
| Gust factor, rideable range, wing size | profile + forecast | 🔧 |
| Lightning none 50 km · 24 h | XDDE | ✅ (fetch on demand; 250 calls a month) |
| Next 3 days wind band | beach forecast is per date (3 calls) | ✅ but costly; days 4–8 🌍 |
| Model agreement: Meteocat WRF 3 km | raw WRF not in the API | ❌ → use "Meteocat forecast" (the beach/municipal value) as one entry |
| AROME 1.3 km, ICON-EU, ECMWF IFS, GFS | Open-Meteo | 🌍 ✅ |
| HARMONIE-AROME (AEMET) | not on Open-Meteo ⚠ | ❌ drop, or AEMET OpenData (only finished forecasts) |
| Ensemble wind P10/P50/P90 | Open-Meteo Ensemble | 🌍 |
| Station check (bias, error, hit rate, 30 days) | our archive of forecasts + XEMA | 🔧 needs about 30 days of logging before it shows anything |

### Surf planner
| Element | Source | Status |
|---|---|---|
| Wave height + direction hourly, water temp | beach forecast | ✅ |
| **Period** row, "groundswell", swell vs wind sea | beach forecast has no period | 🌍 Open-Meteo Marine (`swell_wave_period`, `wave_period`); buoy gives the current period only (XEMA 91/93/95) |
| Swell window | beach orientation (our spot data) + direction | 🔧 |
| Buoy check "Barcelona coast" | XEMA buoy variables 90–97 | ✅ ⚠ which buoys exist is still unverified |
| Model list: Meteocat SWAN | raw not in the API | ❌ → "Meteocat beach forecast" |
| Copernicus MED, ECMWF WAM, GFS WW3 | Open-Meteo Marine (ECMWF WAM, GFS wave, MFWAM) ✅; Copernicus via CMEMS (free account) | 🌍 |
| Puertos del Estado | separate open-data portal, no simple API | ❌ drop |
| "Avoid crowds → weekday quieter" | no data | ❌ keep it as a plain weekday rule or drop |

### Bike planner
| Element | Source | Status |
|---|---|---|
| Temp/feels, rain mm, wind, UV hourly | `municipalHoraria`, `uvi` | ✅ (feels-like ⚠, otherwise compute from temp/RH/wind) |
| Roads dry from 09 h | XEMA 35/70 (rain observed) + ET₀ | 🔧 |
| Gusts on the ride | not in Meteocat forecasts | 🌍 |
| Route wind (58 % tailwind) | wind forecast + **route geometry** | 🔧 + GPX import |
| "Tibidabo climb in 34 min" (FTP, kg) | route elevation profile | ❌ not weather data → needs GPX with elevation or a DEM |
| Sources mention "radar" | not in the API | ❌ remove |

### Run planner
All weather fields fit (`municipalHoraria`, `uvi`, XEMA station) ✅. Pace and finish time come from the profile 🔧.

### Hike planner
| Element | Source | Status |
|---|---|---|
| Summit/hut temps, wind, sky | `pirineu/pics/el-pedraforca`, `refugis` (Pedraforca is in the list) | ✅ ⚠ field list not verified |
| **Storm % per hour** | Meteocat gives symbols/text, not a probability ⚠ | 🌍 Open-Meteo (CAPE + precipitation, ensemble) or show the Meteocat storm symbol |
| Snow level 2300 → 1900 m | possibly in the Pyrenees forecast ⚠ | 🌍 Open-Meteo `freezing_level_height` as fallback |
| Pressure trend | XEMA 34 (station with a barometer) | ✅ |
| Altitude profile | pics + refugi + valley station, with the middle point interpolated | 🔧 |
| "1290 m of ascent: summit at 10:45" | route data | ❌ not weather data → route/GPX |
| Lightning | XDDE | ✅ |

### Activities, Spots, Spot detail, Map
| Element | Source | Status |
|---|---|---|
| Rideable hours heatmap (6 months), "6 years of station history" | needs 30-min XEMA data per day; daily statistics don't give "hours in range" | 🔧 **quota**: backfill = 1 call per station per day → 6 months ≈ 180 calls (OK), 6 years ≈ 2,200 calls (≈ 3 months of the whole XEMA quota) |
| Rideable days per month | as above | 🔧 |
| Gusts "last 10 min" | XEMA resolution is 30 min | ❌ → "last 30 min" |
| Forecast vs measured | archive | 🔧 |
| Map pins, warnings by county | ratings + `smp` + `referencia/comarques` | ✅ |

### Profile and setup
All fields are profile data 🔧. One conflict: the setup flow says **"Your details stay on this
device"**, but the alerts ("a 4 or 5 window appears", "plan changes by a full point") need either
server-side evaluation (the server would need your thresholds) or on-device background checks
(unreliable on iOS). Decide which.

## 3. Station names used in the design
Not found in the 189-station list ⚠ (they may be missing from that list, so verify with the key):

| Design | Status | Nearest listed alternatives |
|---|---|---|
| Barcelona · Zoo | not listed | X4 Barcelona – el Raval, Y7 Port de Barcelona – Bocana Sud, D5 Observatori Fabra |
| Castelldefels | not listed | YY Viladecans – les Filipines, XL el Prat de Llobregat |
| Gósol, Saldes (Pedraforca) | not listed | UI Gisclareny, WV Guardiola de Berguedà, Z9 Cadí Nord 2145 m |
| Sant Cugat | ✅ XV Sant Cugat del Vallès – CAR | |
| Montseny · Turó de l'Home | summit not listed | VX Tagamanent – PN del Montseny |
| Barcelona coastal buoy / Ocata | unknown | check XEMA variables 90–97 |

Rule for the build: never hard-code station names in copy; take them from
`xema/estacions/metadades` and `representatives`.

## 4. Quota reality (free plan, ⚠ numbers unverified)
Forecast calls the design needs per day: Barcelona hourly + daily (2), UV (1), warnings (1),
Castelldefels beach × 3 days (3), Ocata beach × 3 days (3), Pedraforca summit × 3 days (3),
Sant Cugat hourly (1) ≈ **14/day ≈ 420/month** against **≈ 100/month**.

Options:
1. **Open-Meteo as the main forecast source for the planners** (free for non-commercial use, hourly,
   16 days, gusts, marine, ensembles). Meteocat provides observations, warnings, the Today forecast,
   beach forecast for today, and acts as the "Meteocat" entry in the model comparison.
   *Recommended.*
2. Meteocat professional plan (paid) if Meteocat should stay the main source.
3. Fewer planners refreshed daily (e.g. only spots marked as favourites).

## 5. Changes to send back to the design
1. Model agreement: replace "Meteocat WRF 3 km", "Meteocat SWAN", "HARMONIE-AROME (AEMET)" and
   "Puertos del Estado" with "Meteocat forecast" + Open-Meteo models (AROME/ARPEGE, ICON-EU, ECMWF
   IFS, GFS; marine: ECMWF WAM, MFWAM, GFS wave).
2. Ensemble: "51 members (ECMWF ENS)" unless AROME-EPS is confirmed available.
3. "No rain for the next 2 hours" → "Dry for the next 2 hours (forecast)", or drop.
4. Gusts "last 10 min" → "last 30 min"; show the real data age everywhere.
5. Remove "radar" from bike sources.
6. History copy "6 years" → "since <first archived day>" until the backfill is done.
7. Climb time and ascent need route data: add "Import GPX" to Spots, or drop these lines.
8. Drop "Avoid crowds" or label it as a plain weekday rule.
9. Station names must be placeholders filled from station metadata.
10. Privacy line vs alerts: pick on-device alerts or say "alert thresholds are stored on the server".

## 6. Applied (2026-11-10)
All ten changes from §5 were applied to `design/handoff/` (outlines, artboards, planner-logic, READMEs):
model rows → Meteocat finished forecast + Open-Meteo models (ARPEGE replaces HARMONIE, MFWAM and DWD EWAM
replace Copernicus MED and Puertos del Estado); ensemble 67 → 51 ECMWF members; "Dry for the next 2 hours
(forecast)"; gusts "last 30 min"; radar removed; history "archived since setup"; climb/ascent marked
"GPX route"; "Avoid crowds" → the wave range from setup; stations → el Raval, Viladecans, Gisclareny,
Guardiola de Berguedà; privacy line mentions server-side alert thresholds. HANDOFF.md now has a
"Data sources per screen element" table. Source strategy: docs/02 §2.

Still unverified until there's an API key: which buoys exist, whether municipal hourly has rain
probability and feels-like, whether the summit forecast has snow level, and Open-Meteo availability of
DWD EWAM and AROME for all of Catalonia. The `react-source/` bundle in the handoff still has the old
sample text; it's reference code, not shown to users.
