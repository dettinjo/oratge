# Oratge — Flutter app

Weather planner for Catalonia (wing foil, surf, bike, run, hike). The design lives in `design/` (copied from the handoff package).

Read before any UI work:
- @design/HANDOFF.md — screens, architecture, build order, acceptance checks
- @design/design-system/README.md — colour language and hierarchy rules

## Rules
- All colours, sizes, radii and spacing come from `lib/theme/oratge_tokens.dart` (`context.og.*`, `OgText.*`, `OgSpace.*`, `OgRadius.*`). Never use raw hex, `Colors.*` or magic numbers for these.
- One widget per design-system component, named `Og<Component>`, props matching `design/design-system/components/<Name>/<Name>.d.ts`. Check the component's `README.md` before building it.
- Build screens from `design/screens/outline/<device>-<screen>.json` in the listed order; compare with the matching artboard in `design/screens/artboards/`.
- Port chart drawing from `design/design-system/react-source/` into `CustomPainter`s; don't approximate.
- Colour = meaning (wind/water/heat/sun/storm/snow); text never uses accent colours below 20 px.
- Minimum text size 12; touch targets ≥ 44; every chart wrapped in `Semantics(label: <takeaway>)`.
- Support light, dark and system theme everywhere; verify both themes for every screen.
- Sample data first (values in the outlines); keep data behind repository interfaces.

## Commands
- `flutter analyze` and `flutter test` must pass before a task is done.
