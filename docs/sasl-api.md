# API de dibujo SASL — referencia de trabajo

Notas sobre las primitivas `sasl.gl.*` y los helpers de SASL que usa
RCHud. Las firmas marcadas **(verificada)** están confirmadas por el uso
real en `instrumentpanel.lua`; las marcadas **(disponible)** existen en
el runtime pero hay que confirmar su firma exacta antes de usarlas.

## Sistema de coordenadas

- Origen **abajo-izquierda**, eje **Y hacia arriba** (estilo OpenGL/X-Plane).
- Las coordenadas dentro de un componente son **locales** al componente.
- RCHud (heredado de MiniHUD) define una unidad virtual:
  ```lua
  local px = mainFrameHeight * 0.01   -- 1 "px" = 1% del alto del marco
  ```
  Dibujar todo en múltiplos de `px` hace que el HUD escale solo al
  redimensionar la ventana. **Regla:** posiciones y tamaños en `px`, no
  en píxeles absolutos.
- Colores: tabla `{r, g, b, a}` con floats `0.0..1.0`. La transparencia
  es real (no se rellena fondo salvo scrims puntuales).

## Texto

| Función | Firma | Notas |
|---|---|---|
| `sasl.gl.loadFont(path)` | `path` relativo al módulo → handle | Cargar una vez, fuera de `draw()`. |
| `sasl.gl.drawText` | `(font, x, y, text, size, bold, italic, align, color)` | **(verificada)** `bold`/`italic` bool; `align` = `TEXT_ALIGN_LEFT \| _CENTER \| _RIGHT`. |
| `sasl.gl.measureText` | `(font, text, size)` → ancho | **(disponible)** Para centrar y dimensionar scrims. |
| `sasl.gl.drawRotatedText` | `(font, x, y, angle, ...)` | **(disponible)** Texto rotado sin tocar la matriz. |

> SASL **no** dibuja contorno/outline en el texto. Para legibilidad sobre
> fondo variable: scrim oscuro detrás (rect `{0,0,0,~0.4}`) o, más caro,
> redibujar el texto desplazado en negro y encima en blanco.

## Formas (verificadas en uso)

| Función | Firma | Notas |
|---|---|---|
| `drawRectangle` | `(x, y, w, h, color)` | Relleno. Base de barras, scrims, ticks. |
| `drawFrame` | `(x, y, w, h, color)` | Solo contorno. |
| `drawTriangle` | `(x1,y1, x2,y2, x3,y3, color)` | Relleno. Agujas/punteros. |
| `drawCircle` | `(x, y, radius, filled, color)` | `filled` bool. |
| `drawLine` | `(x1,y1, x2,y2, color)` | Línea de 1 px de grosor. |
| `drawPolyLine` | `({x1,y1, x2,y2, ...}, color)` | Polilínea abierta (lista plana de coords). |

## Formas con grosor — clave para el look vectorial RC (disponibles)

El estilo objetivo es **línea fina anti-aliased con halo**. Para eso:

| Función | Uso previsto |
|---|---|
| `drawWideLine` | Línea de grosor controlable. Confirmar firma (`x1,y1,x2,y2,width,color`?). |
| `drawWidePolyLine` | Polilínea con grosor. |
| `drawArc` / `drawArcLine` | Arcos de rango de los diales (verde/amarillo/rojo) sin aproximar con rects. |
| `drawAngle` | Sector angular. |
| `drawBezierLine*` / `drawWideBezierLine*` | Curvas suaves si hiciera falta. |

### Patrón de halo de legibilidad (a implementar como helper)

Dibujar cada trazo **dos veces**:
1. Primero, trazo más grueso en **negro semitransparente** `{0,0,0,0.5}` (halo).
2. Encima, el trazo blanco fino.

```lua
-- pseudo-helper, pendiente de confirmar firma de drawWideLine
local function haloLine(x1,y1,x2,y2, w, color)
    sasl.gl.drawWideLine(x1,y1,x2,y2, w+2, {0,0,0,0.5})  -- halo
    sasl.gl.drawWideLine(x1,y1,x2,y2, w,   color)        -- trazo
end
```

## Transformaciones (matriz, componen — verificadas)

`setTranslateTransform`/`setRotateTransform` **se acumulan** (multiplican
sobre la matriz actual), no son absolutas. Se acotan con save/restore:

```lua
sasl.gl.saveGraphicsContext()
sasl.gl.setTranslateTransform(cx, cy)   -- mueve el origen al centro
sasl.gl.setRotateTransform(-heading)    -- rota
-- ... dibujar en coords locales al centro ...
for i=1,12 do
    sasl.gl.setRotateTransform(30)      -- ¡suma 30° cada vez! (relativo)
    -- dibuja un tick
end
sasl.gl.restoreGraphicsContext()        -- deshace translate+rotate
```

> Confirmado en la brújula de MiniHUD: 12 llamadas a `setRotateTransform(30)`
> reparten ticks cada 30° → la rotación es **relativa/compositiva**.

## Texturas (perf, fase posterior — disponibles)

`createTexture`, `drawTexture*`, `getGLVectorTexture`, etc. Si el número
de instrumentos crece y redibujar todo en vector cada frame pesa, cachear
las **partes estáticas** (ticks, números de un dial) a textura y redibujar
en vector solo lo que se mueve (agujas). Con pocos instrumentos, redibujar
todo cada frame es barato — no optimizar antes de tiempo.

## Recorte a una región (aprendido)

Existen `gl.drawMaskStart` / `gl.drawUnderMask` / `gl.drawMaskEnd`, pero en
las pruebas del ADI **no recortaron** el relleno al disco (el contenido se
dibujó sin clip). Hasta confirmar su uso correcto en el manual oficial
(`https://1-sim.com/files/SASL3Manual.pdf`), **evitar depender de ellas**.

**Técnica robusta usada en el ADI:** construir la geometría ya recortada
en vez de enmascarar. Para rellenar un disco partido por una línea
(horizonte): dibujar el círculo completo de un color y, encima, el
**segmento circular** del otro color como un **abanico de triángulos**
(`drawTriangle`) cuyos vértices están sobre el círculo. Así el relleno
queda dentro del disco por construcción. La línea divisoria se dibuja del
ancho exacto de la **cuerda** (`2·√(R²−d²)`) para que no sobresalga. Ver
el bloque de actitud en `instrumentpanel.lua`.

## Propiedades / datarefs (helpers SASL)

| Helper | Uso |
|---|---|
| `globalPropertyf("ruta/dataref")` | Handle de dataref float. |
| `globalPropertyi(...)` / `globalPropertys(...)` | Variantes int / string. |
| `createGlobalPropertys("ruta", valor)` | Crear propiedad propia (p. ej. versión). |
| `get(prop)` / `set(prop, v)` | Leer / escribir. |
| `sasl.getXPVersion()` | Versión XP (p. ej. `>= 12000`). Usado para elegir dataref de flaps. |

## Ventana, comandos, ratón (de `main.lua`)

- `contextWindow({...})` crea la ventana overlay. Flags relevantes:
  `noDecore`, `noBackground` (transparencia), `noResize=false`
  (redimensionable), `layer = SASL_CW_LAYER_FLIGHT_OVERLAY`,
  `proportional`, `gravity`.
- `loadComponent("nombre")` carga el componente por nombre de archivo
  (sin extensión); la carpeta contenedora ("Custom Module") no se
  referencia por nombre.
- `sasl.createCommand("RCHud/toggleHUD", "desc")` +
  `sasl.registerCommandHandler(cmd, 0, fn)`; en `fn`, `phase` ==
  `SASL_COMMAND_BEGIN` al pulsar. Devolver `0` corta otros callbacks.
- Callbacks del componente: `update()`, `draw()`, `onMouseDown`,
  `onMouseHold` (firmas: `(comp, x, y, button, parentX, parentY)`).
  `isInRect(rect, x, y)` con `rect = {x, y, w, h}`. `MB_LEFT` = botón
  izquierdo. Devolver `false` deja pasar el evento (p. ej. para que la
  ventana se pueda arrastrar).

## Ciclo de vida

- Código a nivel de módulo (cargar fuentes, declarar props/datarefs) se
  ejecuta **una vez** al cargar.
- `update()` se llama cada tick (lógica/estado).
- `draw()` se llama cada frame (solo dibujo; idealmente sin lógica pesada).
