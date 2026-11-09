# Oratge (working name)

A minimalist Android weather app for Catalonia built on the Meteocat API, tuned for wing
foiling, surfing, biking, running and hiking.

- [01 — API analysis](docs/01-api-analysis.md): every known endpoint, variables, quotas
- [02 — Architecture and stack](docs/02-architecture-stack.md): backend cache + quota
  governor on the homelab, Kotlin/Compose app
- [03 — Design](docs/03-design.md): principles, screens, components, activity scoring

## Roadmap
| Phase | Deliverable | Done when |
|---|---|---|
| 0 | Get the API key (all 5 plans); read the real quotas from `/quotes/v1/consum-actual`; record JSON fixtures for every endpoint; list buoy stations | fixtures committed, open ⚠ items in 01 resolved |
| 1 | Backend: ingest jobs, budget governor, Postgres, app API `/v1/home` | runs on Coolify for 7 days within quota |
| 2 | App shell: Today screen, 7-day forecast, offline cache, theme | installable debug APK |
| 3 | Spots + scoring engine + activity detail screens (wing and surf first) | scores match gut feeling on 10 real sessions |
| 4 | Map: stations, wind, lightning, warnings | |
| 5 | History and analysis, widgets, push alerts ("wing window tomorrow") | |
| 6 | Polish: i18n (ca/es/en), accessibility, Play Store internal track | |

## Open decisions
1. Allow Open-Meteo to fill Meteocat's gaps (wave period/swell, gust forecast, >3 days)?
2. Host the backend on the homelab (Coolify), public over HTTPS?
3. Home location and first spots (e.g. Barcelona, a flatwater wing spot, a surf beach)?
4. Personal use only, or Play Store later? Commercial use needs permission from Meteocat.
