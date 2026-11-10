# Planner logic

`planner-logic.json` holds, per sport, the rules the planner screens visualise (values are sample data):

- `ratingFactors` — factor, observed value, weight %, score 0–1, colour meaning. Rating = round(5 × Σ weight × score); the planner shows the total (e.g. 4.4 / 5) and the rounded rating.
- `modelAgreement` — model values at the decisive hour, model weights, blended value, spread and a one-line verdict.
- `stationCheck` — yesterday's blend vs the station/buoy: bias, mean error, hit rate; a positive bias is added as a correction.
- `tunedToYou` — how profile/setup fields change the forecast (e.g. weight + board → minimum rideable wind; storm-risk limit → turn-back time).
- `takeaway` — the sentence shown above the hour chart and used as its accessibility label.
- `analysisSummary` — the chips shown on the collapsed "How this forecast was made" section.

The ensemble chart shows median (line), 90th percentile (shading) and 10th percentile (dashed) from 51 members (ECMWF ENS), plus bars for the chance the user's condition holds.
