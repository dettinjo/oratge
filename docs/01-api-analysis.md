# 01 — Meteocat API analysis

> Status: compiled 2026-11-09 while the official docs site
> (apidocs.meteocat.gencat.cat) was unreachable. Endpoints come from the source of
> five independent open-source clients (meteocatpy, figorr/meteocat HA integration,
> herrera-lu/meteocat-api-client, mariusasensi PHP client, sirwilliamdev/meteocat-mcp).
> Items marked **⚠ verify** must be confirmed against the official docs / a live key.

Base URL: `https://api.meteo.cat` · auth header: `X-Api-Key: <key>` · JSON · dates as `YYYY-MM-DDZ` (UTC).

## 1. Products, plans and quotas

The key is tied to **plans**, each with its own monthly quota. Defaults used by the
Home Assistant integration for the free *Accés ciutadà* plan (**⚠ verify**):

| Plan | Covers | Calls / month | ≈ per day |
|---|---|---|---|
| Referència ("Bàsic") | municipalities, counties, symbols | 2000 | 66 |
| XEMA | station data | 750 | 25 |
| Predicció | all forecasts, UV, warnings | **100** | **3.3** |
| XDDE | lightning | 250 | 8 |
| Quotes | own usage | 300 | 10 |

**Consequence:** the forecast quota is so small that the app can never call Meteocat
directly from the phone. A server-side **fetch-once / cache / serve-many** layer is
mandatory (see 02).

## 2. Endpoint catalogue

### 2.1 Referència (static, fetch once a month)
| Endpoint | Returns | Use |
|---|---|---|
| `/referencia/v1/municipis` | ~947 municipalities, code, name, coords, comarca | location search, forecast keys |
| `/referencia/v1/comarques` | 42 counties | warnings and lightning are per comarca |
| `/referencia/v1/simbols` | sky-state symbol codes → description + icon | map to own minimalist icon set |

### 2.2 XEMA — automatic station network (~180–190 stations, 30-min resolution)
Metadata (cheap, cache weeks):
| Endpoint | Returns |
|---|---|
| `/xema/v1/estacions/metadades[?estat=ope&data=YYYY-MM-DDZ]` | all stations: code, name, coords, altitude, network, status |
| `/xema/v1/estacions/{st}/metadades` | one station |
| `/xema/v1/variables/mesurades/metadades` | catalogue of measured variables (codes below) |
| `/xema/v1/estacions/{st}/variables/mesurades/metadades` | which variables a station measures |
| `/xema/v1/representatives/metadades/variables` and `/representatives/metadades/municipis/{mun}/variables/{var}` | **which station best represents a town for a variable** |
| `/xema/v1/variables/{auxiliars|cmv|estadistics/{diaris|mensuals|anuals}}/metadades` | other catalogues |

Data:
| Endpoint | Returns | Cost-efficiency |
|---|---|---|
| `/xema/v1/estacions/mesurades/{st}/{Y}/{M}/{D}` | **all variables of one station for one day**, every 30 min | 1 call = full day of a spot |
| `/xema/v1/variables/mesurades/{var}/{Y}/{M}/{D}[?codiEstacio=]` | one variable, one day, all stations (or one) | 1 call = whole Catalonia for e.g. wind |
| `/xema/v1/variables/mesurades/{var}/ultimes[?codiEstacio=]` | latest readings of one variable | best for "now" map **⚠ verify window** |
| `/xema/v1/variables/estadistics/diaris/{code}?codiEstacio=&any=&mes=` | daily stats for a month | history / climatology |
| `/xema/v1/variables/estadistics/mensuals/{code}?codiEstacio=&any=` | monthly stats for a year | |
| `/xema/v1/variables/estadistics/anuals/{code}?codiEstacio=` | yearly stats | records, "is today unusual?" |
| `/xema/v1/variables/auxiliars/{code}/{Y}/{M}/{D}?codiEstacio=` | auxiliary variables | low value |
| `/xema/v1/variables/cmv/{code}/{Y}/{M}/{D}?codiEstacio=` | multivariable calculation (6006 = reference evapotranspiration) | low value |

Measured variables that matter to us:

| Code | Variable | Activities |
|---|---|---|
| 30 / 31 | wind speed / direction 10 m (also 6 m: 48/49, 2 m: 46/47) | wing, surf, bike |
| 50 / 51 | **max gust** 10 m + direction | wing (gust factor), bike, hike |
| 32 / 40 / 42 | temperature now / max / min | all |
| 33 / 44 | relative humidity | run (heat stress) |
| 34 | pressure | trend → front arriving |
| 35 / 70 / 72 | precipitation / accumulated / max 1-min intensity | bike (wet roads), hike |
| 36 | global solar irradiance | sun vs cloud, run |
| 39 | UV radiation (MED/h) | run, surf, hike |
| 38 | snow depth | hike |
| **90–96** | **wave buoy: max / significant / mean height (cm), periods (s), peak direction** | **surf, wing** |
| **97** | **sea surface temperature** | wetsuit choice |

Daily statistics codes: 1000–1002 temp, 1100–1102 RH, 1200 pressure, 1300/1302 rain,
1400 irradiation, 1503–1517 wind mean/gust/direction, 1601 snow, 1700 ET0;
monthly 2000–2305 (e.g. 2006 frost days, 2305 rain days); yearly 3000+.

**⚠ verify:** which stations carry the buoy variables 90–97 (probably only a handful of
coastal buoys). Call `/variables/mesurades/92/ultimes` once with a key and list them.

### 2.3 Predicció — forecasts (scarce: ~100 calls / month)
| Endpoint | Content | Horizon |
|---|---|---|
| `/pronostic/v1/municipalHoraria/{mun}` | **hourly** per town: temp, feels-like, RH, precipitation, sky symbol, wind speed + direction | ~72 h |
| `/pronostic/v1/municipal/{mun}` | **daily** per town: min/max, precipitation probability, sky symbol | ~8 days **⚠ verify** |
| `/pronostic/v1/platges/metadades` + `/platges/{slug}/{Y}/{M}/{D}` | **hourly beach forecast**: air temp, RH, wind speed/dir, sky, **wave height, wave direction, water temperature**, UV max/forecast | day by day |
| `/pronostic/v1/pirineu/pics/metadades` + `/pirineu/pics/{slug}/{Y}/{M}/{D}` | summit forecasts (Pedraforca, Puigmal, Pica d'Estats, …) | |
| `/pronostic/v1/pirineu/refugis/metadades` + `/refugis/{slug}/…` | mountain hut forecasts | |
| `/pronostic/v1/pirineu/{Y}/{M}/{D}` | Pyrenees area forecast (text + zones) | |
| `/pronostic/v1/catalunya/{Y}/{M}/{D}` | Catalonia-wide forecast (text, evolution) | |
| `/pronostic/v1/comarcal/{Y}/{M}/{D}` | per-county forecast for a day | |
| `/pronostic/v1/uvi/{mun}` | hourly UV index forecast per town | ~3 days |
| `/pronostic/v2/smp/episodis-oberts[?data=]` | **official warnings** (rain, wind, snow, heat, cold, sea state…): danger level, threshold, per comarca, time window | live |
| `/pronostic/v1/smp/episodis-oberts/preavisos` | pre-warnings | live |

Missing from Meteocat forecasts: **wave period / swell vs wind sea**, **gust forecast**,
**anything more than ~3 days hourly**, air quality, tides (irrelevant in the Med).

### 2.4 XDDE — lightning
| Endpoint | Content |
|---|---|
| `/xdde/v1/catalunya/{Y}/{M}/{D}/{H}` | every strike in one hour: time, lat/lon, current (kA), cloud-to-ground vs intra-cloud |
| `/xdde/v1/informes/comarques/{comarca}/{Y}/{M}/{D}` | daily strike report per county |

### 2.5 Quotes
| `/quotes/v1/consum-actual` | used / remaining per plan → the backend's budget governor reads this |

## 3. What this means for the activities

| Activity | Meteocat gives | Gap → fill from |
|---|---|---|
| Wing foiling | live wind + gusts at coastal stations (30/31/50), beach hourly wind + waves, warnings, lightning | gust **forecast**, >3 day wind, model comparison → Open-Meteo |
| Surfing | buoy height/period/direction/SST (90–97), beach wave height/dir/water temp | swell period/direction forecast → Open-Meteo Marine |
| Biking | hourly temp/rain/wind per town, rain last hours (wet roads), gusts | — |
| Running | hourly temp + RH (heat stress), UV forecast, irradiance | air quality → Open-Meteo AQ (optional) |
| Hiking | summit + hut forecasts, snow depth, warnings, lightning, mountain stations | freezing level → Open-Meteo |

Meteocat stays the primary, attributed source; Open-Meteo (free, no key) fills only the
listed gaps. **Decision for Joel** — see README.
