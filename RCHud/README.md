# RCHud

**HUD overlay para vuelo RC en X-Plane 12.**

Plugin que dibuja un panel de instrumentos mínimo y vectorial sobre la
pantalla, pensado para volar aviones radiocontrol (RC) en vista externa,
sin depender de la cabina del modelo.

Inspirado en el overlay de Aerofly RC y construido sobre
[MiniHUD](https://github.com/bastibe/MiniHUD) de Bastian Bechtold. La
idea es dar al piloto RC, de un vistazo y desde el suelo, solo lo que
necesita: altura sobre el terreno, energía/combustible restante,
distancia y rumbo al punto de despegue, orientación del modelo y
advertencias.

> ⚠️ **Estado: desarrollo temprano (v0.1.0).** Por ahora el plugin
> muestra el set de instrumentos heredado de MiniHUD sin reestilizar.
> Los instrumentos específicos de RC están en construcción (ver más
> abajo).

## Instrumentos

### Actuales (heredados de MiniHUD)

De izquierda a derecha:

1. Indicador de velocidad con zonas de V-speeds.
2. Indicador de trim/control de alerón, elevador y timón.
3. Indicadores de motor: Throttle, Prop y Mixture (arrastrables).
4. Indicador de flaps (arrastrable).
5. Altímetro y variómetro.
6. Brújula con barba de viento.

### Planeados (capa RC)

- [ ] Altura **AGL** (sobre el terreno, no MSL).
- [ ] **Batería + tiempo de vuelo restante** (eléctricos) / **combustible**.
- [ ] **Distancia y rumbo al punto de despegue / piloto**.
- [ ] **Viento relativo a la pista/campo**.
- [ ] **Auxiliar de orientación del modelo** (¿viene o se aleja?).
- [ ] **Anunciadores de advertencia**.
- [ ] **Unidades configurables** (métrico km/h·m ↔ aviación kt·ft).

## Uso

- Arrastra el HUD para reposicionarlo; arrastra una esquina para
  redimensionarlo.
- Asigna un botón al comando **RCHud → show/hide RCHud**
  (`RCHud/toggleHUD`) para mostrar/ocultar el HUD.

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
> código Lua de autor (`data/modules/`) y la documentación. El runtime
> de SASL y los binarios (`64/`, `data/api`, `data/init`,
> `data/components`, librerías nativas) provienen del paquete SASL y se
> superponen al empaquetar — no están en git.

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
