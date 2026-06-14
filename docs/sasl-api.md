# SASL drawing API — working reference

Notes on the `sasl.gl.*` primitives and SASL helpers that RCHud uses.
Signatures marked **(verified)** are confirmed by real use in
`instrumentpanel.lua`; those marked **(available)** exist in the runtime
but their exact signature should be confirmed before use.

## Coordinate system

- Origin at **bottom-left**, **Y axis pointing up** (OpenGL/X-Plane style).
- Coordinates inside a component are **local** to the component.
- RCHud (inherited from MiniHUD) defines a virtual unit:
  ```lua
  local px = mainFrameHeight * 0.01   -- 1 "px" = 1% of the frame height
  ```
  Drawing everything in multiples of `px` makes the HUD scale by itself
  when the window is resized. **Rule:** positions and sizes in `px`, not in
  absolute pixels.
- Colors: `{r, g, b, a}` table with floats `0.0..1.0`. Transparency is real
  (no background is filled in, except for occasional scrims).

## Text

| Function | Signature | Notes |
|---|---|---|
| `sasl.gl.loadFont(path)` | `path` relative to the module → handle | Load once, outside `draw()`. |
| `sasl.gl.drawText` | `(font, x, y, text, size, bold, italic, align, color)` | **(verified)** `bold`/`italic` bool; `align` = `TEXT_ALIGN_LEFT \| _CENTER \| _RIGHT`. |
| `sasl.gl.measureText` | `(font, text, size)` → width | **(available)** For centering and sizing scrims. |
| `sasl.gl.drawRotatedText` | `(font, x, y, angle, ...)` | **(available)** Rotated text without touching the matrix. |

> SASL does **not** draw an outline on text. For legibility over a varying
> background: a dark scrim behind it (rect `{0,0,0,~0.4}`) or, more
> expensive, redraw the text offset in black and on top in white.

## Shapes (verified in use)

| Function | Signature | Notes |
|---|---|---|
| `drawRectangle` | `(x, y, w, h, color)` | Filled. Basis for bars, scrims, ticks. |
| `drawFrame` | `(x, y, w, h, color)` | Outline only. |
| `drawTriangle` | `(x1,y1, x2,y2, x3,y3, color)` | Filled. Needles/pointers. |
| `drawCircle` | `(x, y, radius, filled, color)` | `filled` bool. |
| `drawLine` | `(x1,y1, x2,y2, color)` | 1 px wide line. |
| `drawPolyLine` | `({x1,y1, x2,y2, ...}, color)` | Open polyline (flat coordinate list). |

## Thick shapes — key for the RC vectorial look (available)

The target style is a **thin anti-aliased line with a halo**. For that:

| Function | Intended use |
|---|---|
| `drawWideLine` | Line with controllable thickness. Confirm signature (`x1,y1,x2,y2,width,color`?). |
| `drawWidePolyLine` | Polyline with thickness. |
| `drawArc` / `drawArcLine` | Dial range arcs (green/yellow/red) without approximating with rects. |
| `drawAngle` | Angular sector. |
| `drawBezierLine*` / `drawWideBezierLine*` | Smooth curves if needed. |

### Legibility-halo pattern (to implement as a helper)

Draw each stroke **twice**:
1. First, a slightly thicker stroke in **semi-transparent black**
   `{0,0,0,0.5}` (halo).
2. On top, the thin white stroke.

```lua
-- pseudo-helper, drawWideLine signature still to be confirmed
local function haloLine(x1,y1,x2,y2, w, color)
    sasl.gl.drawWideLine(x1,y1,x2,y2, w+2, {0,0,0,0.5})  -- halo
    sasl.gl.drawWideLine(x1,y1,x2,y2, w,   color)        -- stroke
end
```

## Transforms (matrix, they compose — verified)

`setTranslateTransform`/`setRotateTransform` **accumulate** (they multiply
onto the current matrix), they are not absolute. Bound them with
save/restore:

```lua
sasl.gl.saveGraphicsContext()
sasl.gl.setTranslateTransform(cx, cy)   -- move the origin to the center
sasl.gl.setRotateTransform(-heading)    -- rotate
-- ... draw in coordinates local to the center ...
for i=1,12 do
    sasl.gl.setRotateTransform(30)      -- adds 30° each time! (relative)
    -- draw a tick
end
sasl.gl.restoreGraphicsContext()        -- undoes translate+rotate
```

> Confirmed on the MiniHUD compass: 12 calls to `setRotateTransform(30)`
> spread ticks every 30° → the rotation is **relative/compositional**.

## Textures (perf, later phase — available)

`createTexture`, `drawTexture*`, `getGLVectorTexture`, etc. If the number of
instruments grows and redrawing everything in vector each frame becomes
heavy, cache the **static parts** (ticks, a dial's numbers) to a texture and
redraw in vector only what moves (needles). With few instruments, redrawing
everything every frame is cheap — don't optimize prematurely.

## Clipping to a region (learned)

`gl.drawMaskStart` / `gl.drawUnderMask` / `gl.drawMaskEnd` exist, but in the
ADI tests they **did not clip** the fill to the disc (the content drew
without a clip). Until their correct use is confirmed in the official manual
(`https://1-sim.com/files/SASL3Manual.pdf`), **avoid depending on them**.

**Robust technique used in the ADI:** build the geometry already clipped
instead of masking. To fill a disc split by a line (the horizon): draw the
full circle in one color and, on top, the **circular segment** of the other
color as a **triangle fan** (`drawTriangle`) whose vertices sit on the
circle. That way the fill stays inside the disc by construction. The
dividing line is drawn at the exact width of the **chord** (`2·√(R²−d²)`) so
it doesn't stick out. See the attitude block in `instrumentpanel.lua`.

## Properties / datarefs (SASL helpers)

| Helper | Use |
|---|---|
| `globalPropertyf("path/dataref")` | Float dataref handle. |
| `globalPropertyi(...)` / `globalPropertys(...)` | int / string variants. |
| `globalPropertyfa("path", len)` | **(verified)** **Array** float dataref. `get(prop)` returns a **1-based** table; engine 0 = `[1]`. |
| `createGlobalPropertys("path", value)` | Create your own property (e.g. version). |
| `get(prop)` / `set(prop, v)` | Read / write. |
| `sasl.getXPVersion()` | XP version (e.g. `>= 12000`). Used to pick the flaps dataref. |

> ⚠️ **Array datarefs (learned in RCHud):** passing an index to
> `globalPropertyf("path", i)` does **NOT** index the array — it returns `0`
> with no error. To read an element you must use
> `globalPropertyfa("path", len)` and then `get(prop)[1]` (**1-based**
> table, engine 0 = index 1). Confirmed with `engine_speed_rpm` and
> `N1_percent` (both returned 0 with the index; with `globalPropertyfa` the
> RPM read 1754 on a twin-prop).

## Window, commands, mouse (from `main.lua`)

- `contextWindow({...})` creates the overlay window. Relevant flags:
  `noDecore`, `noBackground` (transparency), `noResize=false` (resizable),
  `layer = SASL_CW_LAYER_FLIGHT_OVERLAY`, `proportional`, `gravity`.
- `loadComponent("name")` loads the component by file name (no extension);
  the containing folder ("Custom Module") is not referenced by name.
- `sasl.createCommand("RCHud/toggleHUD", "desc")` +
  `sasl.registerCommandHandler(cmd, 0, fn)`; in `fn`, `phase` ==
  `SASL_COMMAND_BEGIN` on press. Returning `0` stops other callbacks.
- Component callbacks: `update()`, `draw()`, `onMouseDown`, `onMouseHold`
  (signatures: `(comp, x, y, button, parentX, parentY)`). `isInRect(rect, x,
  y)` with `rect = {x, y, w, h}`. `MB_LEFT` = left button. Returning `false`
  lets the event pass through (e.g. so the window can be dragged).

## Lifecycle

- Module-level code (loading fonts, declaring props/datarefs) runs **once**
  on load.
- `update()` is called every tick (logic/state).
- `draw()` is called every frame (drawing only; ideally no heavy logic).
