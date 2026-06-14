# RCHud — proyecto

HUD overlay para vuelo RC en X-Plane 12, derivado de
[MiniHUD](https://github.com/bastibe/MiniHUD) (SASL, GPLv3).

Este es el **repositorio de desarrollo**. El plugin en sí vive en
[`RCHud/`](RCHud/).

## Estructura del repo

| Ruta | Qué es |
|---|---|
| [`RCHud/`](RCHud/) | El plugin. Se versiona solo el Lua de autor en `RCHud/data/modules/`; el runtime de SASL y binarios quedan fuera (ver `.gitignore`). |
| [`docs/`](docs/) | Documentación técnica de trabajo. |
| [`hud-rc-xplane12-brief.md`](hud-rc-xplane12-brief.md) | Brief original del proyecto (objetivos, decisiones, plan por fases). |
| `LICENSE` | GPLv3. |
| `MiniHUD/` *(local, no versionado)* | Paquete original de MiniHUD, como referencia. |

## Documentación

- [`docs/sasl-api.md`](docs/sasl-api.md) — referencia de la API de dibujo
  SASL (`gl.*`) que usa RCHud.
- [`docs/mapa-instrumentos.md`](docs/mapa-instrumentos.md) — mapa
  instrumento → código de `instrumentpanel.lua`, con datarefs y veredicto
  RC por instrumento.

## Estado

**v0.1.0** — HUD funcional y verificado en vuelo. Estación de control en
tierra con franja horizontal a todo el ancho:

- Altura **AGL** con cinta, línea de tierra y variómetro.
- **Velocidad** y **potencia** como diales circulares (potencia = RPM /
  %N1 / % gases según el tipo de motor).
- **Actitud (ADI)** azul/café y **brújula norte-arriba** con silueta del
  modelo.
- **Tren** en planta real con color por estado (abajo / tránsito / arriba)
  y **flaps** con porcentaje.
- Menú **Plugins ▸ RCHud** (Show HUD / Units / Opacity / Background) +
  comandos asignables a la emisora; **unidades** métrico ↔ aviación;
  **opacidad** y **panel de fondo** ajustables; preferencias persistentes.

Siguiente (en hold): panel de **mapa** del tercio derecho (pista cercana /
punto "home"), viento relativo a pista y anunciadores. Ver el plan por
fases en el brief.

## Licencia

GPLv3. RCHud © 2026 Juan Luis Gabriel; derivado de MiniHUD © 2023 Bastian
Bechtold. Ver [LICENSE](LICENSE).
