# RC HUD Overlay for X-Plane 12 — project brief

> Working document for development in Claude Code.
> Free and open-source project (GPLv3).

---

## 1. Goal

Build a **HUD overlay** for X-Plane 12 aimed at **RC flight** (radio-
controlled aircraft), showing the relevant flight information over the
screen when flying in external view, without relying on the aircraft's
cockpit.

Inspired by the **Aerofly RC** overlay, but **not** a copy: the design is
adapted to what an RC pilot actually needs and to the capabilities of
X-Plane 12.

Reference use case: using it alongside fleets like **VSKYLABS RC-Elements
(RCE)** for X-Plane 12 (electric, glow, turbine, helicopters, VTOL).

---

## 2. Context and references

- **Aerofly RC** — reference for the *idea* (minimal vectorial overlay:
  airspeed dial, heading rose, vertical-speed indicator, altitude/time
  block). The goal is not to replicate it as-is.
- **VSKYLABS RC-Elements Vol.1** — commercial add-on of giant-scale RC
  aircraft for X-Plane 12. Reference market/use.
- **MiniHUD** (`github.com/bastibe/MiniHUD`) — **the basis of the project**
  (see section 4).

---

## 3. Decisions made (and why)

| Decision | Choice | Rationale |
|---|---|---|
| Starting point | **Fork MiniHUD** | It already solves a draggable/resizable overlay, cross-platform, with minimal vectorial instruments. Don't reinvent the scaffolding. |
| Framework | **SASL** (the one MiniHUD already uses) | By forking something that works, the SASL friction is already paid. Self-contained plugin, no recompiling binaries. |
| Language | **Lua** (on SASL) | It's what MiniHUD ships with; editable and readable. |
| License | **GPLv3** | MiniHUD is GPLv3; since the project is free and open, keeping it GPLv3 is no obstacle — it's consistent. |
| Discarded | FlyWithLua / XPPython3 from scratch | Good for a hobby from scratch, but here we already have a working SASL base. |

**Note on the "haiku philosophy":** keep the overlay minimal and clean.
Every instrument must justify its place on screen; if it doesn't help an RC
pilot at a glance, it's out.

---

## 4. Technical base: MiniHUD / SASL

### What it is
An X-Plane plugin (XP11/12; Win, macOS Intel+ARM, Linux) that draws a small
instrument panel for flying without seeing the cockpit. Draggable and
resizable. GPLv3.

### Package structure
```
MiniHUD/
├─ 64/            # compiled SASL core (.xpl) — runtime, NOT author's code
├─ data/
│  └─ modules/    # author's Lua code (the instruments) ← work HERE
├─ liblinux/      # SASL native libs (+ libmac/ libwin equivalents)
├─ README.md
└─ compress.sh    # possible module-packaging script
```

### Key point (resolved)
- The **binaries** in the downloaded package are the **SASL runtime**, not
  author's code. That's why the repo only versions the Lua and the zip also
  ships the binaries. This is the normal practice.
- **The binaries are never touched or recompiled.** Only the Lua in
  `data/modules/` is edited; SASL re-runs it when X-Plane restarts. **Zero
  C/C++ toolchain.**
- **To check when opening the package:** whether the files in `data/modules`
  are plain `.lua` (directly editable) or packed/compiled (in which case,
  take the source `.lua` from the repo and replace).

### Drawing
- SASL's own 2D graphics API.
- **Transparency:** the background is not filled; only the instrument lines
  are drawn and the rest shows the scene through. Transparency "comes for
  free".

---

## 5. Visual style

Aesthetic goal: **thin, anti-aliased, white vectorial line**, with very
sparing color accents (red needle, green range arc). The quality depends on
AA, the halo and the typography, not on the framework.

### Legibility over a varying background (sky / grass / runway)
The central problem of an RC HUD: a white line disappears over a cloud; a
dark one, over asphalt in shadow.

**Standard technique:** draw each element **twice**:
1. First a slightly thicker stroke in **semi-transparent black** (rgba
   ~0,0,0,0.5) as a halo/outline.
2. On top, the white stroke.

For text blocks, a cheaper alternative: a very faint dark *scrim* behind it
(black rectangle ~25% alpha).

### Building a dial (pattern)
1. Define the angular range (e.g. ~270°) and a `value → angle` function.
2. Draw ticks: radial lines (long for majors, short for minors).
3. Numeric labels inward from each major tick.
4. Range arc (color) as short segments hugging the edge.
5. Needle: line/triangle from the center, rotated to the value's angle.

**Performance:** with few instruments, redrawing everything each frame is
cheap. If it grows, cache the static parts (ticks, numbers) to a texture and
redraw in vector only what moves.

---

## 6. Instruments

### Current MiniHUD set (inherited)
- Airspeed with V-speed zones
- Trim/control indicator (aileron/elevator/rudder + current input)
- Throttle / Prop / Mixture
- Flaps
- Altitude + vertical speed
- Compass with wind barb

### RC design layer (what's "right for X-Plane")
RC flight is **line-of-sight from the ground**: the overlay shouldn't mimic
a full glass cockpit, but give what the RC pilot needs at a glance.

To **add / prioritize**:
- [ ] **AGL height** (not ASL): models fly low.
- [ ] **Battery + remaining flight time** (electric); **fuel** for
  glow/turbine.
- [ ] **Wind relative to the runway/field**.
- [ ] **Model-orientation aid** (silhouette/arrow: is it coming toward me or
  going away?). *The #1 RC problem.*
- [ ] **Warning annunciators** (fit RCE's Test-Pilot Mode: failures,
  over-stress, etc.).

To **keep** from MiniHUD:
- Trim/control indicator (useful when flying with a transmitter).
- Airspeed, altitude, vertical speed, compass (restyled).

To **evaluate/remove**: anything that doesn't help an RC pilot (review
case by case).

---

## 7. Candidate datarefs (verify exact strings)

> These are standard X-Plane candidates; confirm names and units in a
> session. Some (battery/fuel) may vary by model in RCE.

- Airspeed: `sim/flightmodel/position/indicated_airspeed`
- MSL altitude: `sim/flightmodel/position/elevation` (m)
- AGL height: `sim/flightmodel/position/y_agl` (m)
- Vertical speed: `sim/flightmodel/position/vh_ind_fpm`
- Heading: `sim/flightmodel/position/mag_psi` / `true_psi`
- Wind: check the `sim/weather/aircraft/wind_*` family (to verify)
- Throttle: `sim/cockpit2/engine/actuators/throttle_ratio_all`
- Battery/fuel: **to verify per aircraft** (electric vs glow vs turbine)
- Control surfaces / trim: `sim/cockpit2/controls/*` and
  `sim/flightmodel2/controls/*` families

---

## 8. Development plan (for Claude Code)

### Phase 0 — Setup
- [ ] Copy the downloaded MiniHUD to a working directory; `git init`; commit
  the intact base.
- [ ] Confirm it's SASL (structure `64/` + `data/modules/` + `liblinux/`).
- [ ] Check whether `data/modules` is plain `.lua` or packed (define the
  editing flow).

### Phase 1 — Understand the base
- [ ] Inventory the components: map each instrument → its Lua file.
- [ ] Document the SASL drawing API it uses (primitives, colors, text,
  transforms).
- [ ] Validate the iteration loop: edit a trivial value → restart XP → see
  the change.

### Phase 2 — Restyle to the RC vectorial look
- [ ] Implement the **legibility-halo** helper (semi-transparent black
  below, white on top).
- [ ] Restyle the kept gauges to the thin-line style.

### Phase 3 — RC instruments
- [ ] AGL
- [ ] Battery + remaining time / fuel
- [ ] Wind relative to the runway
- [ ] Model-orientation aid
- [ ] Warning annunciators

### Phase 4 — Configuration and robustness
- [ ] Reuse MiniHUD's drag/resize.
- [ ] Config: which instruments to show, units (km/h vs kt, m vs ft).
- [ ] Graceful handling of missing datarefs depending on the model (electric
  vs turbine).

### Phase 5 — Testing and release
- [ ] Test across several RCE aircraft (electric, turbine, heli).
- [ ] README + credits to MiniHUD (Bastian Bechtold) and SASL.
- [ ] Release under **GPLv3**.

---

## 9. Open questions

1. Does `data/modules` come as plain `.lua` or packed?
2. Default units: metric (km/h, m) like Aerofly, or configurable?
3. Which RCE aircraft as the first test target?
4. How do RCE aircraft expose battery/fuel per model? (map the real
   datarefs)

---

## 10. Constraints and license

- **License: GPLv3** (inherited from MiniHUD). Keep the fork GPLv3; credit
  the original author and SASL.
- **No recompiling binaries**: only the Lua in `data/modules` is edited.
- Verify **SASL** license terms for distribution (free/open use; confirm).
- Keep the overlay **minimal and clean**: every instrument must earn its
  place.
