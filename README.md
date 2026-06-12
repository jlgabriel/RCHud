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

Desarrollo temprano (v0.1.0). Hecho: base renombrada y funcionando,
documentada. Siguiente: reestilizar al look vectorial RC + primeros
instrumentos RC (AGL, energía, home). Ver el plan por fases en el brief.

## Licencia

GPLv3. RCHud © 2026 Juan Luis Gabriel; derivado de MiniHUD © 2023 Bastian
Bechtold. Ver [LICENSE](LICENSE).
