# Screens

- `outline/<device>-<screen>.json` — one per screen (dark theme; light uses identical structure). A tree of:
  - `{"component": "FactTile", "props": {...}, "children": [...]}` — a design-system component with its exact props.
  - `{"el": "section" | "header" | "details" | "nav" | "h1" | "p" | "button", ...}` — layout and text. `details` has `collapsedByDefault`.
  - `{"link": "<artboard file>", "label": ...}` — navigation target (map file names to routes; `Main.dc.html` = phone Today).
  - `{"input": "text" | "checkbox" | "radio", "value": ..., "label": ..., "checked": true}` — form fields in Profile and the setup flow.
- `artboards/` — the original design files for every screen, device and theme; `index.json` lists them. Visual reference only (they need the design canvas runtime to render).
