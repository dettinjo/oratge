# design-sync notes — @oratge/ui

- This package exists **only as the design source for Claude Design**. The production app is Flutter; keep tokens in `src/tokens.ts` / `src/styles.css` in step with the Flutter theme.
- Build: `npm run build` (esbuild → dist/index.js, tsc declarations). Converter: run from `design-system/` with `--node-modules ./node_modules --entry ./dist/index.js`.
- Playwright: this host has the cached Chromium build `chromium-1228`, so `.ds-sync` uses **playwright@1.61.0** (1.58 pins 1208 and fails). Install it into `.ds-sync` after re-staging the scripts.
- Fonts: DM Sans via `@fontsource/dm-sans` (300–700) wired through `extraFonts`. No remote font loading.
- Nearly every component is phone-width (≈350 px), so most need `cardMode: "column"` (in config). Add it for any new wide component, or GRID_OVERFLOW fires.
- `provider` = `OratgeRoot` with `padded`, so previews get the dark background and font.
- All preview data is invented sample data (Catalan places), not live Meteocat values.

## Known render warns
- none (validate is clean as of 2026-11-09)

## Re-sync risks
- `.ds-sync` pins playwright 1.61.0 to the local Chromium cache. A different machine needs the matching version (see base skill §4.1).
- Colours exist in three places: `src/tokens.ts`, `src/styles.css`, and the conventions header. Change them together.
- First sync was graded by Claude only. The user's review of `.review.html` and of the Claude Design project still counts as the final check.
