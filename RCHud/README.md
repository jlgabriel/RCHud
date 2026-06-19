# RCHud

**HUD overlay for RC flight in X-Plane 12.**

A plugin that draws a minimal, vectorial instrument strip over the screen,
designed as a **ground control station** for flying radio-controlled (RC)
aircraft in external view, without relying on the model's cockpit. At a
glance, from the ground, the RC pilot sees only what they need: height
above terrain, engine power, attitude, heading, gear and flap state.

Inspired by the Aerofly RC overlay and built on top of
[MiniHUD](https://github.com/bastibe/MiniHUD) by Bastian Bechtold (SASL,
GPLv3).

> **Status: v0.3.0.** Functional HUD, verified in flight across several
> models (piston, turbofan with N1, jet without N1, and electric).

## Instruments

A horizontal strip anchored full-width along the bottom of the screen.
From left to right:

- **AGL height** — true height above terrain (not MSL), with a vertical
  tape, a ground line and a **vertical-speed indicator**.
- **Speed** — analog circular dial with reference bands anchored to the
  model's V-speeds (e.g. `Vne`). The source is selectable: **GPS ground
  speed** (`GS`, the default — what most RC models actually carry) or
  **indicated airspeed** (`IAS`). The label shows which one is live.
- **Attitude (ADI)** — blue/brown artificial horizon showing the model's
  pitch and roll. The horizon line stays pinned to the rim at extreme
  attitudes, so a vertical climb/dive never leaves the disc solid.
- **Power** — circular dial whose metric is chosen by **engine type**: RPM
  for piston, **%N1** for a turbine that exposes it, or **throttle %**
  (THR) for electric / jet without N1.
- **Heading** — **north-up** compass with an aircraft silhouette that
  rotates to show the model's orientation, plus a numeric readout.
- **Landing gear** — drawn in its **true planform** (reads which legs the
  model has and where they sit). Colored by state: **green** down,
  **amber** in transit, dim when up. Auto-detects fixed gear.
- **Flaps** — vertical bar with position and percentage.
- **Energy reserve** — a vertical "battery" bar next to the flaps, chosen
  automatically by **engine type**: **battery** state of charge + pack
  voltage for electric models, or **fuel** remaining + quantity for
  combustion. The fuel reading is the actual pre-flight load against the
  real tank size (not assumed full), and the bar is colored **green /
  amber / red** as the reserve drops.

The **right third is left empty on purpose**, keeping the instruments
compact and the scene behind them clear.

## Controls

Everything is driven from the **Plugins ▸ RCHud** menu or with commands you
can bind to your transmitter / joystick. The HUD is **read-only**: you fly
with the transmitter, there is no mouse interaction.

| Menu | Command (bindable) | What it does |
|---|---|---|
| **Show HUD** | `RCHud/toggleHUD` | Show / hide the HUD. |
| **Units ▸ Metric / Aviation** | `RCHud/toggleUnits` | Toggle units **metric** (km/h, m, m/s) ↔ **aviation** (kt, ft, fpm). |
| **Speed source ▸ GPS / IAS** | `RCHud/toggleSpeedSource` | Toggle the speed dial between **GPS ground speed** and **indicated airspeed**. |
| **Opacity** | `RCHud/cycleOpacity` | Global HUD opacity (100 % … 15 %). |
| **Background** | `RCHud/cycleBackground` | Optional grey backing panel (Off / 15 / 25 / 40 / 60 %) for bright backgrounds. |

Preferences (visibility, units, speed source, opacity and background) are
**saved automatically** and restored on restart.

## Installation

Copy the `RCHud` folder into `X-Plane 12/Resources/plugins`. The layout
should look like this:

<pre>
📂 X-Plane 12
└ 📂 Resources
  └ 📂 plugins
    └ 📂 RCHud
      ├ 📁 64
      ├ 📁 data
      ├ 📁 liblinux   (or libmac / libwin depending on platform)
      └ 📄 README.md</pre>

> **Note for developers:** this repository versions only the author's Lua
> code (`data/modules/`) and the documentation. The SASL runtime and
> binaries (`64/`, `data/api`, `data/init`, `data/components`, native
> libraries) come from the SASL package and are overlaid when packaging —
> they are not in git.

## Compatibility

Built on SASL, like MiniHUD: X-Plane 11 and 12, on Windows, macOS (Intel +
ARM) and Linux.

## Credits

- **MiniHUD** — the basis of this project. Copyright (C) 2023 Bastian
  Bechtold. Resized by TreeBaron.
- **SASL** — the scripting/avionics framework (1-sim) the plugin runs on.

## License

RCHud
Copyright (C) 2026 Juan Luis Gabriel

Derived from MiniHUD, Copyright (C) 2023 Bastian Bechtold.

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.

It is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

See the [LICENSE](../LICENSE) file or <https://www.gnu.org/licenses/> for
the full text.
