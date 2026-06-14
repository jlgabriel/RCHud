# Instrument map — `instrumentpanel.lua`

Inventory of the inherited MiniHUD base: what each block draws, which
datarefs it reads, and the **RC verdict** (what we do in RCHud). Line
numbers refer to the current file
[instrumentpanel.lua](../RCHud/data/modules/Custom%20Module/instrumentpanel.lua)
(after adding the license header, +7 lines vs. the original).

> Note: this document describes the **original inherited base**. It is kept
> as a starting-point reference; the current HUD has since been reworked
> into a ground control station (see the project README).

## Overall structure

- **Datarefs** (lines ~20–47): all the `globalPropertyf` handles.
- **`update()`** (~66–85): sets the initial proportional size once.
- **`draw()`** (~88–307): redraws the whole HUD every frame.
- **`onMouseDown` / `onMouseHold`** (~310–345): dragging of
  throttle/prop/mixture/flaps.

The layout is anchored to `airspeedFrameWidth = 150` (tall left column) and
a main frame `mainFrameWidth = width - 180`. Each instrument is placed at a
fraction of that frame (`mainFrameWidth * 0.10`, `0.30`, …).

## Blocks

### 1. Airspeed — ~108–140
- **Dataref:** `sim/cockpit2/gauges/indicators/airspeed_kts_pilot`.
- **V-speeds:** `acf_Vne`, `acf_Vfe`, `acf_Vno`, `acf_Vso`, `acf_Vs`
  (`sim/aircraft/view/...`). They define the green/yellow/red zones.
- **Drawing:** vertical bar with color arcs (rects), a double triangle as a
  needle, "%.0f KTS" text. Orange if above Vne or IAS<0 with AGL>10.
- **RC verdict: keep, restyle.** Move to thin line + halo. Configurable
  units (kt↔km/h). A model's V-speeds may be poorly defined → handle
  missing/0 values.

### 2. Trim / control — ~145–160
- **Datarefs:** `aileron_trim`, `elevator_trim`, `rudder_trim`
  (`sim/cockpit2/controls/`); current input `yoke_heading_ratio`,
  `yoke_pitch_ratio`, `yoke_roll_ratio`.
- **Drawing:** three axes (cross + rudder bar), trim mark (rect) and input
  bar per axis.
- **RC verdict: keep, restyle.** Very useful when flying with a transmitter
  (see the real stick/trim positions).

### 3. Engine quadrant (Throttle / Prop / Mixture) — ~166–183
- **Datarefs:** `throttle_ratio_all`, `prop_ratio_all`, `mixture_ratio_all`
  (`sim/cockpit2/engine/actuators/`).
- **Drawing:** three vertical bars with a "ball" (circle) at the position;
  **draggable** (see `*Rect` + `onMouseDown/Hold`).
- **RC verdict: evaluate/trim down.** For electric RC, prop and mixture are
  unneeded. Likely: keep throttle only, or replace the block with
  **battery/energy** depending on engine type (electric vs glow/turbine).

### 4. Flaps — ~189–194
- **Dataref:** `flap_handle_request_ratio` (XP12) / `flap_ratio` (XP11);
  selected by `sasl.getXPVersion()`.
- **Drawing:** vertical bar with a mark; draggable.
- **RC verdict: keep optional.** Many RC models have no flaps → hide if the
  model doesn't use them.

### 5. Altitude + vertical speed — ~200–233
- **Datarefs:** altitude `altitude_ft_pilot`; vertical speed `vvi_fpm_pilot`
  (`sim/cockpit2/gauges/indicators/`). Also reads `y_agl`
  (`sim/flightmodel/position/`) in the airspeed block.
- **Drawing:** MSL altitude tape with numbers every 100 ft + a value box;
  side VVI needle labeled "%+.0f".
- **RC verdict: replace the core with AGL.** RC models fly low: the relevant
  height is **AGL** (`y_agl`, in meters), not MSL. Keep the restyled
  vertical-speed indicator. Configurable units (ft↔m).

### 6. Compass + wind — ~239–305
- **Datarefs:** heading `ground_track_mag_pilot`; wind `wind_heading_deg_mag`
  and `wind_speed_kts` (`sim/cockpit2/gauges/indicators/`).
- **Drawing:** circle with N/S/E/W and ticks every 30° (uses accumulating
  transforms), HDG box, and a **wind barb** (triangles/long/short, weather-
  chart style) rotated to the wind direction relative to the rose.
- **RC verdict: keep, restyle; add an RC layer.** Wind relative to the
  runway/field is very relevant in RC. The **bearing to "home"** (takeoff
  point) also fits here as an arrow over the rose.

## Candidate datarefs for the RC layer (to verify in XP12)

| Need | Candidate dataref | Unit |
|---|---|---|
| AGL height | `sim/flightmodel/position/y_agl` | m |
| Vertical speed | `sim/flightmodel/position/vh_ind_fpm` | fpm |
| Position (home) | `sim/flightmodel/position/latitude` / `longitude` | ° |
| True/mag heading | `sim/flightmodel/position/true_psi` / `mag_psi` | ° |
| Wind (family) | `sim/weather/aircraft/wind_*` | verify |
| Battery/fuel | **depends on the model (RCE)** | verify |

> **Open design questions** (from the brief, affecting this layer): the
> **"home"** point (takeoff auto-detection vs. a manual `RCHud/setHome`
> command), and how each RC-Elements aircraft exposes battery/fuel. Resolve
> with a concrete test model.

## Interaction (dragging)

`throttleRect`, `propRect`, `mixtureRect`, `flapsRect` are recomputed in
`draw()` and queried in `onMouseDown`/`onMouseHold` with `isInRect`. A
pattern to reuse for any new draggable control.
