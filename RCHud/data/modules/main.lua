-- RCHud — HUD overlay para vuelo RC en X-Plane 12
-- Copyright (C) 2026 Juan Luis Gabriel
-- Derivado de MiniHUD, Copyright (C) 2023 Bastian Bechtold
--
-- Programa libre bajo GPLv3 o posterior (ver LICENSE).
-- Distribuido SIN GARANTÍA. Ver <https://www.gnu.org/licenses/>.

-- set up SASL preferences:
sasl.options.setAircraftPanelRendering(false)
sasl.options.set3DRendering(false)
sasl.options.setInteractivity(false)

local rcHudVersionProp = createGlobalPropertys("RCHud/version", "v0.1.0")
sasl.logInfo("RCHud version:", get(rcHudVersionProp))

-- These are hard-coded and should never really change
-- they are based on the visual settings TreeBaron
-- used when boosting the font size
local startHeight = 540
local startWidth = 945

local localState = {
   windowScale = 0.7, -- Change THIS if you want to rescale the start size (the ratio will not change)
   windowStartX = 50, -- Change THIS if you want to change where the window starts
   windowStartY = 50,
   windowHeight = startHeight,
   windowWidth = startWidth,
   contextWindow = nil,
   setStartScale = false
}

local instrumentPanel = loadComponent("instrumentpanel")
local instrumentWindow = contextWindow({
    name = "RCHud";
    position = { 50, 50, startWidth, startHeight};
    saveState = false;
    noDecore = true;
    noBackground = true;
    noResize = false;
    visible = true;
    proportional = true;
    gravity = {0, 0, 0, 0}; -- stick to the left bottom
    vrAuto = true;
    layer = SASL_CW_LAYER_FLIGHT_OVERLAY;
    components = {
        instrumentPanel {
            position = { 0, 0, startWidth, startHeight };
            localState = localState;
        }
    }
})

localState.contextWindow = instrumentWindow;

-- create a command for toggling the HUD on and off
local toggleHUDCommand = sasl.createCommand("RCHud/toggleHUD", "show/hide RCHud")
sasl.registerCommandHandler(toggleHUDCommand, 0, function (phase)
    if phase == SASL_COMMAND_BEGIN then
        instrumentWindow:setIsVisible(not instrumentWindow:isVisible())
    end
    return 0 -- don't allow other callbacks to run
end)
