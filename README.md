# RCHud — project

HUD overlay for RC flight in X-Plane 12, derived from
[MiniHUD](https://github.com/bastibe/MiniHUD) (SASL, GPLv3).

This is the **development repository**. The plugin itself lives in
[`RCHud/`](RCHud/).

## Repo layout

| Path | What it is |
|---|---|
| [`RCHud/`](RCHud/) | The plugin. Only the author's Lua under `RCHud/data/modules/` is versioned; the SASL runtime and binaries are kept out (see `.gitignore`). |
| [`docs/`](docs/) | Working technical documentation. |
| [`hud-rc-xplane12-brief.md`](hud-rc-xplane12-brief.md) | Original project brief (goals, decisions, phased plan). |
| `LICENSE` | GPLv3. |
| `MiniHUD/` *(local, not versioned)* | Original MiniHUD package, kept as reference. |

## Documentation

- [`docs/sasl-api.md`](docs/sasl-api.md) — reference for the SASL drawing
  API (`gl.*`) that RCHud uses.
- [`docs/instrument-map.md`](docs/instrument-map.md) — instrument → code
  map of `instrumentpanel.lua`, with datarefs and an RC verdict per
  instrument.

## Status

**v0.3.0** — functional HUD, verified in flight. Ground control station
with a full-width horizontal strip:

- **AGL** height with tape, ground line and vertical-speed indicator.
- **Speed** and **power** as circular dials. Speed source is selectable
  between **GPS ground speed** (default, what most RC models carry) and
  **indicated airspeed**; power = RPM / %N1 / throttle % depending on
  engine type.
- **Attitude (ADI)** blue/brown and a **north-up compass** with a
  silhouette of the model.
- **Landing gear** in true planform, colored by state (down / in
  transit / up), and **flaps** with percentage.
- **Energy reserve** as a vertical bar, chosen by engine type: **battery**
  charge + voltage for electric models, or **fuel** remaining + quantity
  (against the real tank capacity) for combustion; colored by level.
- **Plugins ▸ RCHud** menu (Show HUD / Units / Opacity / Background) plus
  bindable commands; **units** metric ↔ aviation; adjustable **opacity**
  and **background panel**; persistent preferences.

Next (on hold): runway-relative wind and annunciators. See the phased plan
in the brief.

## License

GPLv3. RCHud © 2026 Juan Luis Gabriel; derived from MiniHUD © 2023 Bastian
Bechtold. See [LICENSE](LICENSE).
