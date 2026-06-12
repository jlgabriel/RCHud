# Mapa de instrumentos — `instrumentpanel.lua`

Inventario de la base heredada de MiniHUD: qué dibuja cada bloque, qué
datarefs lee, y el **veredicto RC** (qué hacemos en RCHud). Líneas
referidas al archivo actual
[instrumentpanel.lua](../RCHud/data/modules/Custom%20Module/instrumentpanel.lua)
(tras añadir la cabecera de licencia, +7 líneas vs. el original).

## Estructura general

- **Datarefs** (líneas ~20–47): todos los handles `globalPropertyf`.
- **`update()`** (~66–85): fija el tamaño inicial proporcional una vez.
- **`draw()`** (~88–307): redibuja todo el HUD cada frame.
- **`onMouseDown` / `onMouseHold`** (~310–345): arrastre de
  throttle/prop/mixture/flaps.

El layout se ancla a `airspeedFrameWidth = 150` (columna izquierda alta) y
un marco principal `mainFrameWidth = ancho - 180`. Cada instrumento se
coloca a una fracción de ese marco (`mainFrameWidth * 0.10`, `0.30`, …).

## Bloques

### 1. Velocidad (airspeed) — ~108–140
- **Dataref:** `sim/cockpit2/gauges/indicators/airspeed_kts_pilot`.
- **V-speeds:** `acf_Vne`, `acf_Vfe`, `acf_Vno`, `acf_Vso`, `acf_Vs`
  (`sim/aircraft/view/...`). Definen las zonas verde/amarillo/rojo.
- **Dibujo:** barra vertical con arcos de color (rects), doble triángulo
  como aguja, texto "%.0f KTS". Naranja si sobre Vne o IAS<0 con AGL>10.
- **Veredicto RC: conservar, reestilizar.** Pasar a línea fina + halo.
  Unidades configurables (kt↔km/h). Las V-speeds de un modelo RC pueden no
  estar bien definidas → manejar valores ausentes/0.

### 2. Trim / control — ~145–160
- **Datarefs:** `aileron_trim`, `elevator_trim`, `rudder_trim`
  (`sim/cockpit2/controls/`); input actual `yoke_heading_ratio`,
  `yoke_pitch_ratio`, `yoke_roll_ratio`.
- **Dibujo:** tres ejes (cruz + barra rudder), marca de trim (rect) y
  barra de input por eje.
- **Veredicto RC: conservar, reestilizar.** Muy útil volando con
  transmisora (ver posición real de los sticks/trims).

### 3. Quadrante de motor (Throttle / Prop / Mixture) — ~166–183
- **Datarefs:** `throttle_ratio_all`, `prop_ratio_all`,
  `mixture_ratio_all` (`sim/cockpit2/engine/actuators/`).
- **Dibujo:** tres barras verticales con "esfera" (círculo) en la
  posición; **arrastrables** (ver `*Rect` + `onMouseDown/Hold`).
- **Veredicto RC: evaluar/recortar.** Para eléctricos RC, prop y mixture
  sobran. Probable: dejar solo throttle, o reemplazar el bloque por
  **batería/energía** según tipo de motor (eléctrico vs glow/turbina).

### 4. Flaps — ~189–194
- **Dataref:** `flap_handle_request_ratio` (XP12) / `flap_ratio` (XP11);
  selección por `sasl.getXPVersion()`.
- **Dibujo:** barra vertical con marca; arrastrable.
- **Veredicto RC: conservar opcional.** Muchos modelos RC no tienen
  flaps → ocultar si el modelo no los usa.

### 5. Altitud + variómetro — ~200–233
- **Datarefs:** altitud `altitude_ft_pilot`; variómetro `vvi_fpm_pilot`
  (`sim/cockpit2/gauges/indicators/`). También lee
  `y_agl` (`sim/flightmodel/position/`) en el bloque de velocidad.
- **Dibujo:** cinta de altitud MSL con números cada 100 ft + caja del
  valor; aguja de VVI lateral con etiqueta "%+.0f".
- **Veredicto RC: reemplazar el núcleo por AGL.** Los modelos RC vuelan
  bajo: la altura relevante es **AGL** (`y_agl`, en metros), no MSL.
  Conservar el variómetro reestilizado. Unidades configurables (ft↔m).

### 6. Brújula + viento — ~239–305
- **Datarefs:** rumbo `ground_track_mag_pilot`; viento
  `wind_heading_deg_mag` y `wind_speed_kts`
  (`sim/cockpit2/gauges/indicators/`).
- **Dibujo:** círculo con N/S/E/O y ticks cada 30° (usa transformaciones
  acumulativas), caja de HDG, y **barba de viento** (triángulos/largas/
  cortas estilo carta meteorológica) rotada a la dirección del viento
  relativa a la rosa.
- **Veredicto RC: conservar, reestilizar; añadir capa RC.** El viento
  relativo a la pista/campo es muy relevante en RC. Aquí encaja también
  el **rumbo a "home"** (punto de despegue) como flecha sobre la rosa.

## Datarefs candidatos para la capa RC (a verificar en XP12)

| Necesidad | Dataref candidato | Unidad |
|---|---|---|
| Altura AGL | `sim/flightmodel/position/y_agl` | m |
| Variómetro | `sim/flightmodel/position/vh_ind_fpm` | fpm |
| Posición (home) | `sim/flightmodel/position/latitude` / `longitude` | ° |
| Rumbo verdadero/mag | `sim/flightmodel/position/true_psi` / `mag_psi` | ° |
| Viento (familia) | `sim/weather/aircraft/wind_*` | verificar |
| Batería/combustible | **depende del modelo (RCE)** | verificar |

> **Pendientes de diseño** (preguntas abiertas del brief que afectan a
> esta capa): punto **"home"** (autodetección de despegue vs. comando
> manual `RCHud/setHome`), y cómo expone batería/combustible cada
> aeronave RC-Elements. Resolver con un modelo de prueba concreto.

## Interacción (arrastre)

`throttleRect`, `propRect`, `mixtureRect`, `flapsRect` se recalculan en
`draw()` y se consultan en `onMouseDown`/`onMouseHold` con `isInRect`.
Patrón a reutilizar para cualquier control arrastrable nuevo.
