-- RCHud - HUD overlay for RC flight in X-Plane 12
-- Copyright (C) 2026 Juan Luis Gabriel
-- Derived from MiniHUD, Copyright (C) 2023 Bastian Bechtold
--
-- Free software under GPLv3 or later (see LICENSE).
-- Distributed WITHOUT WARRANTY. See <https://www.gnu.org/licenses/>.

-- set up SASL preferences:
sasl.options.setAircraftPanelRendering(false)
sasl.options.set3DRendering(false)
sasl.options.setInteractivity(false)

local rcHudVersionProp = createGlobalPropertys("RCHud/version", "v0.3.0")
sasl.logInfo("RCHud version:", get(rcHudVersionProp))

-- HUD logical canvas (aspect ratio of the horizontal strip).
-- instrumentpanel.lua draws in coordinates 0..startWidth x 0..startHeight and
-- SASL scales it proportionally to the real window. update() fits the window
-- to the FULL WIDTH of the screen, anchored at the bottom (horizontal strip).
local startWidth = 1600
local startHeight = 270   -- ~6:1 -> low full-width strip, minimally intrusive

local localState = {
   windowHeight = startHeight,
   windowWidth = startWidth,
   contextWindow = nil,
   units = "metric",  -- "metric" (km/h, m, m/s) | "aviation" (kt, ft, fpm). Toggle with RCHud/toggleUnits
   speedSource = "gps", -- "gps" (GPS ground speed, default) | "ias" (airspeed). Toggle with RCHud/toggleSpeedSource
   opacity = 1.0,     -- HUD opacity 0..1 (1 = opaque). Set from Plugins > RCHud > Opacity
   bgOpacity = 0.0    -- grey backing panel 0..1 (0 = off). Set from Plugins > RCHud > Background
}

local instrumentPanel = loadComponent("instrumentpanel")
local instrumentWindow = contextWindow({
    name = "RCHud";
    position = { 0, 0, startWidth, startHeight};
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

------------------------------------------------------------------------
-- Persistence. Settings (visibility, units, opacity, background) are written
-- to a small Lua file next to main.lua and reloaded on startup, so the HUD
-- comes back configured the way you left it. Best-effort: any I/O failure is
-- ignored and the HUD simply falls back to its defaults.
------------------------------------------------------------------------
local SETTINGS_PATH = getProjectPath() .. "/rchud_settings.lua"

local function saveSettings()
    local f = io.open(SETTINGS_PATH, "w")
    if f == nil then return end
    f:write(string.format(
        "return {\n  visible = %s,\n  units = %q,\n  speedSource = %q,\n  opacity = %s,\n  bgOpacity = %s,\n}\n",
        tostring(instrumentWindow:isVisible()),
        localState.units,                       -- %q quotes and escapes the string
        localState.speedSource,
        tostring(localState.opacity or 1.0),
        tostring(localState.bgOpacity or 0.0)))
    f:close()
end

-- Load saved settings into localState (and window visibility) BEFORE the menu
-- is built, so the initial checkmarks match what was restored.
do
    local chunk = loadfile(SETTINGS_PATH)
    if chunk ~= nil then
        local ok, t = pcall(chunk)
        if ok and type(t) == "table" then
            if type(t.units) == "string"       then localState.units = t.units end
            if type(t.speedSource) == "string" then localState.speedSource = t.speedSource end
            if type(t.opacity) == "number"     then localState.opacity = t.opacity end
            if type(t.bgOpacity) == "number" then localState.bgOpacity = t.bgOpacity end
            if t.visible == false then instrumentWindow:setIsVisible(false) end
            sasl.logInfo("RCHud settings loaded:", SETTINGS_PATH)
        end
    end
end

------------------------------------------------------------------------
-- Shared state helpers. Both the Plugins menu and the commands route
-- through these so the menu checkmarks always reflect the live state.
------------------------------------------------------------------------
-- Menu handles, filled in when the menu is built below.
local rcHudMenuId, unitsMenuId, speedMenuId, opacityMenuId, bgMenuId
local menuShowItem, menuUnitsMetric, menuUnitsAviation
local menuSpeedGps, menuSpeedIas
local menuOpacityItems = {}
local menuBgItems = {}
-- Discrete opacity levels offered in the menu (and cycled by the command).
-- Coarser near opaque, finer toward transparent (where it reads differently).
local OPACITY_LEVELS = {
    {1.0, "100%"}, {0.8, "80%"}, {0.6, "60%"}, {0.5, "50%"},
    {0.4, "40%"}, {0.3, "30%"}, {0.2, "20%"}, {0.15, "15%"},
}
-- Grey backing-panel levels. 0.0 = off (the panel is not drawn at all).
local BG_LEVELS = { {0.0, "Off"}, {0.15, "15%"}, {0.25, "25%"}, {0.4, "40%"}, {0.6, "60%"} }

local function refreshMenu()
    if menuShowItem ~= nil then
        sasl.setMenuItemState(rcHudMenuId, menuShowItem,
            instrumentWindow:isVisible() and MENU_CHECKED or MENU_UNCHECKED)
    end
    if menuUnitsMetric ~= nil then
        local metric = (localState.units ~= "aviation")
        sasl.setMenuItemState(unitsMenuId, menuUnitsMetric,   metric and MENU_CHECKED or MENU_UNCHECKED)
        sasl.setMenuItemState(unitsMenuId, menuUnitsAviation, metric and MENU_UNCHECKED or MENU_CHECKED)
    end
    if menuSpeedGps ~= nil then
        local gps = (localState.speedSource ~= "ias")
        sasl.setMenuItemState(speedMenuId, menuSpeedGps, gps and MENU_CHECKED or MENU_UNCHECKED)
        sasl.setMenuItemState(speedMenuId, menuSpeedIas, gps and MENU_UNCHECKED or MENU_CHECKED)
    end
    for i, lv in ipairs(OPACITY_LEVELS) do
        local item = menuOpacityItems[i]
        if item ~= nil then
            local on = math.abs((localState.opacity or 1.0) - lv[1]) < 0.01
            sasl.setMenuItemState(opacityMenuId, item, on and MENU_CHECKED or MENU_UNCHECKED)
        end
    end
    for i, lv in ipairs(BG_LEVELS) do
        local item = menuBgItems[i]
        if item ~= nil then
            local on = math.abs((localState.bgOpacity or 0.0) - lv[1]) < 0.01
            sasl.setMenuItemState(bgMenuId, item, on and MENU_CHECKED or MENU_UNCHECKED)
        end
    end
end

local function setHudVisible(visible)
    instrumentWindow:setIsVisible(visible)
    refreshMenu()
    saveSettings()
end

local function toggleHud()
    setHudVisible(not instrumentWindow:isVisible())
end

local function setUnits(units)
    localState.units = units
    sasl.logInfo("RCHud units:", localState.units)
    refreshMenu()
    saveSettings()
end

local function toggleUnits()
    setUnits(localState.units == "aviation" and "metric" or "aviation")
end

local function setSpeedSource(src)
    localState.speedSource = src
    sasl.logInfo("RCHud speed source:", localState.speedSource)
    refreshMenu()
    saveSettings()
end

local function toggleSpeedSource()
    setSpeedSource(localState.speedSource == "ias" and "gps" or "ias")
end

local function setOpacity(value)
    localState.opacity = value
    sasl.logInfo("RCHud opacity:", value)
    refreshMenu()
    saveSettings()
end

local function cycleOpacity()
    local cur = localState.opacity or 1.0
    local idx = 1
    for i, lv in ipairs(OPACITY_LEVELS) do
        if math.abs(cur - lv[1]) < 0.01 then idx = i; break end
    end
    setOpacity(OPACITY_LEVELS[(idx % #OPACITY_LEVELS) + 1][1])  -- step down, wrap to 100%
end

local function setBackground(value)
    localState.bgOpacity = value
    sasl.logInfo("RCHud background opacity:", value)
    refreshMenu()
    saveSettings()
end

local function cycleBackground()
    local cur = localState.bgOpacity or 0.0
    local idx = 1
    for i, lv in ipairs(BG_LEVELS) do
        if math.abs(cur - lv[1]) < 0.01 then idx = i; break end
    end
    setBackground(BG_LEVELS[(idx % #BG_LEVELS) + 1][1])  -- step up, wrap back to Off
end

------------------------------------------------------------------------
-- Plugins menu: Plugins > RCHud > [Show HUD | Units | Opacity | Background]
------------------------------------------------------------------------
local rcHudMenuItem = sasl.appendMenuItem(PLUGINS_MENU_ID, "RCHud")
rcHudMenuId = sasl.createMenu("RCHud", PLUGINS_MENU_ID, rcHudMenuItem)

-- Show HUD: checkable, mirrors the window visibility.
menuShowItem = sasl.appendMenuItem(rcHudMenuId, "Show HUD", toggleHud)

-- Units submenu: the active mode is checked (radio-style).
local unitsMenuItem = sasl.appendMenuItem(rcHudMenuId, "Units")
unitsMenuId = sasl.createMenu("Units", rcHudMenuId, unitsMenuItem)
menuUnitsMetric   = sasl.appendMenuItem(unitsMenuId, "Metric (km/h, m, m/s)", function() setUnits("metric") end)
menuUnitsAviation = sasl.appendMenuItem(unitsMenuId, "Aviation (kt, ft, fpm)", function() setUnits("aviation") end)

-- Speed source submenu: GPS ground speed (realistic for RC) or indicated airspeed.
local speedMenuItem = sasl.appendMenuItem(rcHudMenuId, "Speed source")
speedMenuId = sasl.createMenu("Speed source", rcHudMenuId, speedMenuItem)
menuSpeedGps = sasl.appendMenuItem(speedMenuId, "GPS (ground speed)", function() setSpeedSource("gps") end)
menuSpeedIas = sasl.appendMenuItem(speedMenuId, "IAS (airspeed)", function() setSpeedSource("ias") end)

-- Opacity submenu: discrete levels, the active one is checked.
local opacityMenuItem = sasl.appendMenuItem(rcHudMenuId, "Opacity")
opacityMenuId = sasl.createMenu("Opacity", rcHudMenuId, opacityMenuItem)
for i, lv in ipairs(OPACITY_LEVELS) do
    menuOpacityItems[i] = sasl.appendMenuItem(opacityMenuId, lv[2], function() setOpacity(lv[1]) end)
end

-- Background submenu: grey backing panel, "Off" or a level (checked when active).
local bgMenuItem = sasl.appendMenuItem(rcHudMenuId, "Background")
bgMenuId = sasl.createMenu("Background", rcHudMenuId, bgMenuItem)
for i, lv in ipairs(BG_LEVELS) do
    menuBgItems[i] = sasl.appendMenuItem(bgMenuId, lv[2], function() setBackground(lv[1]) end)
end

refreshMenu()  -- set the initial checkmarks

------------------------------------------------------------------------
-- Commands (joystick/keyboard bindable). They share the helpers above so
-- the menu stays in sync when toggled from a hardware binding.
------------------------------------------------------------------------
-- toggle the HUD on and off
local toggleHUDCommand = sasl.createCommand("RCHud/toggleHUD", "Show/hide RCHud")
sasl.registerCommandHandler(toggleHUDCommand, 0, function (phase)
    if phase == SASL_COMMAND_BEGIN then toggleHud() end
    return 0 -- don't allow other callbacks to run
end)

-- toggle units live (metric <-> aviation)
local toggleUnitsCommand = sasl.createCommand("RCHud/toggleUnits", "Toggle units metric/aviation")
sasl.registerCommandHandler(toggleUnitsCommand, 0, function (phase)
    if phase == SASL_COMMAND_BEGIN then toggleUnits() end
    return 0 -- don't allow other callbacks to run
end)

-- toggle speed source live (GPS ground speed <-> indicated airspeed)
local toggleSpeedSourceCommand = sasl.createCommand("RCHud/toggleSpeedSource", "Toggle speed source GPS/IAS")
sasl.registerCommandHandler(toggleSpeedSourceCommand, 0, function (phase)
    if phase == SASL_COMMAND_BEGIN then toggleSpeedSource() end
    return 0 -- don't allow other callbacks to run
end)

-- cycle HUD opacity (100% -> 80% -> ... -> 15% -> 100%)
local cycleOpacityCommand = sasl.createCommand("RCHud/cycleOpacity", "Cycle HUD opacity")
sasl.registerCommandHandler(cycleOpacityCommand, 0, function (phase)
    if phase == SASL_COMMAND_BEGIN then cycleOpacity() end
    return 0 -- don't allow other callbacks to run
end)

-- cycle the grey background panel (Off -> 15% -> 25% -> 40% -> 60% -> Off)
local cycleBackgroundCommand = sasl.createCommand("RCHud/cycleBackground", "Cycle HUD background panel")
sasl.registerCommandHandler(cycleBackgroundCommand, 0, function (phase)
    if phase == SASL_COMMAND_BEGIN then cycleBackground() end
    return 0 -- don't allow other callbacks to run
end)
