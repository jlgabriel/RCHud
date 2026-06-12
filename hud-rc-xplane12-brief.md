# HUD Overlay RC para X-Plane 12 — Brief de proyecto

> Documento de trabajo para desarrollar en Claude Code.
> Proyecto libre y de código abierto (GPLv3).

---

## 1. Objetivo

Construir un **HUD overlay** para X-Plane 12 orientado a **vuelo RC** (aviones radiocontrol), que muestre la información de vuelo relevante sobre la pantalla cuando se vuela en vista externa, sin depender de la cabina del avión.

Inspirado en el overlay de **Aerofly RC**, pero **no** una copia: el diseño se adapta a lo que un piloto RC realmente necesita y a las capacidades de X-Plane 12.

Caso de uso de referencia: usarlo junto a flotas como **VSKYLABS RC-Elements (RCE)** para X-Plane 12 (eléctricos, glow, turbinas, helicópteros, VTOL).

---

## 2. Contexto y referencias

- **Aerofly RC** — referencia de la *idea* (overlay minimalista vectorial: dial de velocidad, rosa de rumbo, variómetro, bloque de altitud/tiempo). No es el objetivo replicarlo tal cual.
- **VSKYLABS RC-Elements Vol.1** — add-on comercial de aviones RC giant-scale sobre X-Plane 12. Mercado/uso de referencia.
- **MiniHUD** (`github.com/bastibe/MiniHUD`) — **base del proyecto** (ver sección 4).

---

## 3. Decisiones tomadas (y por qué)

| Decisión | Elección | Justificación |
|---|---|---|
| Punto de partida | **Forkear MiniHUD** | Ya resuelve overlay arrastrable/redimensionable, multiplataforma, con instrumentos vectoriales minimalistas. No reinventar el andamiaje. |
| Framework | **SASL** (el que ya usa MiniHUD) | Al forkear algo que funciona, la fricción de SASL ya está pagada. Plugin autocontenido, sin recompilar binarios. |
| Lenguaje | **Lua** (sobre SASL) | Es lo que trae MiniHUD; editable y legible. |
| Licencia | **GPLv3** | MiniHUD es GPLv3; como el proyecto es libre y abierto, mantenerlo GPLv3 no es obstáculo, es coherente. |
| Descartado | FlyWithLua / XPPython3 desde cero | Buenos para hobby desde cero, pero aquí ya tenemos una base SASL funcionando. |

**Nota sobre la "filosofía haiku":** mantener el overlay mínimo y limpio. Cada instrumento debe justificar su lugar en pantalla; si no aporta a un piloto RC de un vistazo, no va.

---

## 4. Base técnica: MiniHUD / SASL

### Qué es
Plugin de X-Plane (XP11/12; Win, macOS Intel+ARM, Linux) que dibuja un panel pequeño de instrumentos para volar sin ver la cabina. Arrastrable y redimensionable. GPLv3.

### Estructura del paquete
```
MiniHUD/
├─ 64/            # núcleo SASL compilado (.xpl) — runtime, NO es código del autor
├─ data/
│  └─ modules/    # código Lua del autor (los instrumentos) ← AQUÍ se trabaja
├─ liblinux/      # libs nativas de SASL (+ libmac/ libwin equivalentes)
├─ README.md
└─ compress.sh    # posible script de empaquetado de módulos
```

### Punto clave (resuelto)
- Los **binarios** del paquete descargado son el **runtime de SASL**, no código del autor. Por eso el repo solo versiona el Lua y el zip trae además los binarios. Es la práctica normal.
- **No se tocan ni recompilan los binarios.** Se edita solo el Lua en `data/modules/`; SASL lo re-ejecuta al reiniciar X-Plane. **Cero toolchain de C/C++.**
- **A verificar al abrir el paquete:** si los archivos de `data/modules` son `.lua` planos (editables directo) o vienen empacados/compilados (en ese caso, tomar los `.lua` fuente del repo y reemplazar).

### Dibujo
- API de gráficos 2D propia de SASL.
- **Transparencia:** no se rellena el fondo; solo se dibujan las líneas del instrumento y el resto queda viendo la escena. La transparencia "sale gratis".

---

## 5. Estilo visual

Objetivo estético: **línea vectorial fina, anti-aliased, blanca**, con acentos de color muy puntuales (aguja roja, arco de rango verde). La calidad depende del AA, el halo y la tipografía, no del framework.

### Legibilidad sobre fondo variable (cielo / pasto / pista)
Problema central de un HUD RC: una línea blanca desaparece sobre una nube; una oscura, sobre asfalto en sombra.

**Técnica estándar:** dibujar cada elemento **dos veces**:
1. Primero un trazo algo más grueso en **negro semitransparente** (rgba ~0,0,0,0.5) como halo/contorno.
2. Encima, el trazo blanco.

Para bloques de texto, alternativa más barata: un *scrim* oscuro muy tenue detrás (rectángulo negro ~25% alfa).

### Construcción de un dial (patrón)
1. Definir rango angular (p. ej. ~270°) y función `valor → ángulo`.
2. Dibujar ticks: líneas radiales (largas para mayores, cortas para menores).
3. Etiquetas numéricas hacia adentro de cada tick mayor.
4. Arco de rango (color) como segmentos cortos pegados al borde.
5. Aguja: línea/triángulo desde el centro, rotada al ángulo del valor.

**Rendimiento:** con pocos instrumentos, redibujar todo cada frame es barato. Si crece, cachear las partes estáticas (ticks, números) a textura y redibujar en vector solo lo que se mueve.

---

## 6. Instrumentos

### Set actual de MiniHUD (heredado)
- Velocidad con zonas de V-speeds
- Indicador de trim/control (aileron/elevator/rudder + input actual)
- Throttle / Prop / Mixture
- Flaps
- Altitud + variómetro
- Brújula con barba de viento

### Capa de diseño RC (lo "adecuado para X-Plane")
El vuelo RC es de **línea de vista desde el suelo**: el overlay no debe imitar un glass cockpit completo, sino dar lo que el piloto RC necesita de un vistazo.

A **agregar / priorizar**:
- [ ] **Altura AGL** (no ASL): los modelos vuelan bajo.
- [ ] **Batería + tiempo de vuelo restante** (eléctricos); **combustible** para glow/turbina.
- [ ] **Distancia y rumbo al punto de despegue / piloto**: los modelos se alejan y se hacen diminutos.
- [ ] **Viento relativo a la pista/campo**.
- [ ] **Auxiliar de orientación del modelo** (silueta/flecha: ¿viene hacia mí o se aleja?). *Problema nº1 del RC.*
- [ ] **Anunciadores de advertencia** (encajan con el Test-Pilot Mode de RCE: fallas, sobre-estrés, etc.).

A **conservar** de MiniHUD:
- Indicador de trim/control (útil volando con transmisora).
- Velocidad, altitud, variómetro, brújula (reestilizados).

A **evaluar/quitar**: lo que no aporte a un piloto RC (revisar caso a caso).

---

## 7. Datarefs candidatos (verificar strings exactos)

> Son candidatos estándar de X-Plane; confirmar nombres y unidades en sesión. Algunos (batería/combustible) pueden variar por modelo en RCE.

- Velocidad: `sim/flightmodel/position/indicated_airspeed`
- Altitud MSL: `sim/flightmodel/position/elevation` (m)
- Altura AGL: `sim/flightmodel/position/y_agl` (m)
- Variómetro: `sim/flightmodel/position/vh_ind_fpm`
- Rumbo: `sim/flightmodel/position/mag_psi` / `true_psi`
- Posición: `sim/flightmodel/position/latitude`, `.../longitude` (para distancia/rumbo a "home")
- Viento: revisar familia `sim/weather/aircraft/wind_*` (a verificar)
- Throttle: `sim/cockpit2/engine/actuators/throttle_ratio_all`
- Batería/combustible: **a verificar por aeronave** (eléctrico vs glow vs turbina)
- Superficies de control / trim: familia `sim/cockpit2/controls/*` y `sim/flightmodel2/controls/*`

**"Home" para distancia/rumbo:** decidir si se autodetecta el punto de despegue o se fija con un *command* asignable (recomendado: command "set home point").

---

## 8. Plan de desarrollo (para Claude Code)

### Fase 0 — Setup
- [ ] Copiar el MiniHUD descargado a un directorio de trabajo; `git init`; commit base intacto.
- [ ] Confirmar que es SASL (estructura `64/` + `data/modules/` + `liblinux/`).
- [ ] Verificar si `data/modules` es `.lua` plano o empacado (definir flujo de edición).

### Fase 1 — Entender la base
- [ ] Inventariar componentes: mapear cada instrumento → su archivo Lua.
- [ ] Documentar la API de dibujo SASL que usa (primitivas, colores, texto, transformaciones).
- [ ] Validar el loop de iteración: editar un valor trivial → reiniciar XP → ver el cambio.

### Fase 2 — Reestilizar al look vectorial RC
- [ ] Implementar el helper de **halo de legibilidad** (negro semitransparente debajo, blanco encima).
- [ ] Reestilizar los gauges conservados al estilo línea fina.

### Fase 3 — Instrumentos RC
- [ ] AGL
- [ ] Batería + tiempo restante / combustible
- [ ] Distancia + rumbo a "home" (con command para fijar home)
- [ ] Viento relativo a pista
- [ ] Auxiliar de orientación del modelo
- [ ] Anunciadores de advertencia

### Fase 4 — Configuración y robustez
- [ ] Reusar drag/resize de MiniHUD.
- [ ] Config: qué instrumentos mostrar, unidades (km/h vs kt, m vs ft).
- [ ] Manejo elegante de datarefs ausentes según modelo (eléctrico vs turbina).

### Fase 5 — Pruebas y publicación
- [ ] Probar en varias aeronaves RCE (eléctrico, turbina, heli).
- [ ] README + créditos a MiniHUD (Bastian Bechtold) y a SASL.
- [ ] Publicar bajo **GPLv3**.

---

## 9. Preguntas abiertas

1. ¿`data/modules` viene en `.lua` plano o empacado?
2. Unidades por defecto: ¿métrico (km/h, m) como Aerofly, o configurable?
3. "Home" para distancia/rumbo: ¿autodetección de despegue o command manual?
4. ¿Cuál aeronave RCE como primer objetivo de prueba?
5. ¿Cómo exponen RCE la batería/combustible por modelo? (mapear datarefs reales)

---

## 10. Restricciones y licencia

- **Licencia: GPLv3** (heredada de MiniHUD). Mantener el fork GPLv3; acreditar autor original y SASL.
- **No recompilar binarios**: solo se edita Lua en `data/modules`.
- Verificar términos de licencia de **SASL** para distribución (uso libre/abierto; confirmar).
- Mantener el overlay **mínimo y limpio**: cada instrumento debe ganarse su lugar.
