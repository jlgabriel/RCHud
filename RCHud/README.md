# RCHud

**HUD overlay para vuelo RC en X-Plane 12.**

Plugin que dibuja una franja de instrumentos mínima y vectorial sobre la
pantalla, pensada como **estación de control en tierra** para volar
aviones radiocontrol (RC) en vista externa, sin depender de la cabina del
modelo. De un vistazo, desde el suelo, el piloto RC ve solo lo que
necesita: altura sobre el terreno, energía del motor, actitud, rumbo,
estado del tren y de los flaps.

Inspirado en el overlay de Aerofly RC y construido sobre
[MiniHUD](https://github.com/bastibe/MiniHUD) de Bastian Bechtold (SASL,
GPLv3).

> 📷 _Captura del HUD en vuelo — pendiente de añadir._

> **Estado: v0.1.0.** HUD funcional y verificado en vuelo con varios
> modelos (pistón, turbofan con N1, jet sin N1). El panel de **mapa** del
> tercio derecho está reservado para una versión futura.

## Instrumentos

Franja horizontal anclada a todo el ancho en la parte inferior de la
pantalla. De izquierda a derecha:

- **Altura AGL** — altura real sobre el terreno (no MSL), con cinta
  vertical, línea de tierra y **variómetro** (velocidad vertical).
- **Velocidad** — dial circular analógico con bandas de referencia
  ancladas a las V-speeds del modelo (p. ej. `Vne`).
- **Actitud (ADI)** — horizonte artificial azul/café con cabeceo y
  alabeo del modelo.
- **Potencia** — dial circular cuya métrica se elige según el **tipo de
  motor**: RPM en pistón, **%N1** en turbina que lo expone, o **% de
  gases** (THR) en eléctrico / jet sin N1.
- **Rumbo** — brújula **NORTE-ARRIBA** con una silueta de avión que gira
  para mostrar la orientación del modelo, y lectura numérica.
- **Tren de aterrizaje** — dibujado en su **planta real** (lee qué patas
  tiene el modelo y dónde van). Color por estado: **verde** abajo,
  **ámbar** en tránsito, apagado arriba. Autodetecta tren fijo.
- **Flaps** — barra vertical con la posición y el porcentaje.

El **tercio derecho se deja libre a propósito**, reservado para un futuro
panel de mapa (pista cercana / punto "home").

## Controles

Todo se maneja desde el menú **Plugins ▸ RCHud** o con comandos
asignables a la emisora / joystick. El HUD es **solo lectura**: se vuela
con la emisora, no se interactúa con el ratón.

| Menú | Comando (asignable) | Qué hace |
|---|---|---|
| **Show HUD** | `RCHud/toggleHUD` | Muestra / oculta el HUD. |
| **Units ▸ Metric / Aviation** | `RCHud/toggleUnits` | Alterna unidades **métrico** (km/h, m, m/s) ↔ **aviación** (kt, ft, fpm). |
| **Opacity** | `RCHud/cycleOpacity` | Opacidad global del HUD (100 % … 15 %). |
| **Background** | `RCHud/cycleBackground` | Panel de fondo gris opcional (Off / 15 / 25 / 40 / 60 %) para fondos claros. |

Las preferencias (visibilidad, unidades, opacidad y fondo) se **guardan
automáticamente** y se restauran al reiniciar.

## Instalación

Copia la carpeta `RCHud` a `X-Plane 12/Resources/plugins`. La estructura
debe quedar así:

<pre>
📂 X-Plane 12
└ 📂 Resources
  └ 📂 plugins
    └ 📂 RCHud
      ├ 📁 64
      ├ 📁 data
      ├ 📁 liblinux   (o libmac / libwin según plataforma)
      └ 📄 README.md</pre>

> **Nota para desarrolladores:** este repositorio versiona únicamente el
> código Lua de autor (`data/modules/`) y la documentación. El runtime de
> SASL y los binarios (`64/`, `data/api`, `data/init`, `data/components`,
> librerías nativas) provienen del paquete SASL y se superponen al
> empaquetar — no están en git.

## Compatibilidad

Construido sobre SASL, igual que MiniHUD: X-Plane 11 y 12, en Windows,
macOS (Intel + ARM) y Linux.

## Créditos

- **MiniHUD** — base del proyecto. Copyright (C) 2023 Bastian Bechtold.
  Redimensionado por TreeBaron.
- **SASL** — framework de scripting/avionics (1-sim) sobre el que corre
  el plugin.

## Licencia

RCHud
Copyright (C) 2026 Juan Luis Gabriel

Derivado de MiniHUD, Copyright (C) 2023 Bastian Bechtold.

Este programa es software libre: puedes redistribuirlo y/o modificarlo
bajo los términos de la Licencia Pública General GNU publicada por la
Free Software Foundation, en su versión 3 o (a tu elección) cualquier
versión posterior.

Se distribuye con la esperanza de que sea útil, pero SIN NINGUNA
GARANTÍA; ni siquiera la garantía implícita de COMERCIABILIDAD o
IDONEIDAD PARA UN PROPÓSITO PARTICULAR. Consulta la Licencia Pública
General GNU para más detalles.

Ver el archivo [LICENSE](../LICENSE) o
<https://www.gnu.org/licenses/> para el texto completo.
