-- RCHud - instrument panel (HUD drawing)
-- Copyright (C) 2026 Juan Luis Gabriel
-- Derived from MiniHUD, Copyright (C) 2023 Bastian Bechtold
--
-- Free software under GPLv3 or later (see LICENSE).
-- Distributed WITHOUT WARRANTY. See <https://www.gnu.org/licenses/>.
--
-- PHASE A: ground control station. Full-width horizontal layout; airspeed
-- and RPM/N1 as circular dials; AGL tape + VSI; NORTH-UP compass with an
-- aircraft silhouette that rotates to heading (model orientation).
-- Removed vs MiniHUD: trim, prop/mixture, mouse control and wind.

local sourceCodePro = sasl.gl.loadFont("fonts/SourceCodePro.ttf")
local white = {1.0, 1.0, 1.0, 1.0}
local green = {0.2, 0.9, 0.2, 1.0}
local yellow = {0.9, 0.9, 0.2, 1.0}
local red = {0.9, 0.2, 0.2, 1.0}
local orange = {0.9, 0.5, 0.2, 1.0}
local lightGrey = {0.8, 0.8, 0.8, 1.0}
local background = {0.0, 0.0, 0.0, 0.4}

-- Backing panel style (the optional grey panel drawn behind everything in
-- draw()). Cool dark blue-grey ("gunmetal"), inset by a small margin with a
-- subtle lighter border. The alpha comes from localState.bgOpacity at runtime.
local BG_COLOR   = {0.13, 0.16, 0.22}    -- panel fill
local BG_BORDER  = {0.42, 0.50, 0.62}    -- thin frame, a lighter cool grey
local BG_MARGIN_X, BG_MARGIN_Y = 16, 12  -- inset from the strip edges (logical px)

------------------------------------------------------------------------
-- Global HUD opacity
-- Every draw primitive multiplies its color alpha by hudOpacity (0..1), read
-- from localState.opacity at the top of draw(). Implemented by wrapping the
-- sasl.gl primitives once here: the color is always the LAST argument, so we
-- scale args[n] when it is an {r,g,b,a} table. At opacity 1.0 the wrapper is a
-- pass-through (no allocation). sasl.gl is a plain table (see data/api/api.lua),
-- so reassigning its fields is safe; the pcall is a guard so any failure here
-- never breaks drawing (the HUD just stays fully opaque).
------------------------------------------------------------------------
local hudOpacity = 1.0
local unpack = table.unpack or unpack

local function installOpacity(name)
    local orig = sasl.gl[name]
    sasl.gl[name] = function(...)
        if hudOpacity >= 0.999 then return orig(...) end
        local n = select("#", ...)
        local c = select(n, ...)
        if type(c) == "table" and #c == 4 then
            local args = {...}
            args[n] = {c[1], c[2], c[3], c[4] * hudOpacity}
            return orig(unpack(args, 1, n))
        end
        return orig(...)
    end
end

-- Raw (unwrapped) rectangle + frame for the background panel: their alpha is
-- exactly localState.bgOpacity, independent of the global instrument opacity.
local rawRect = sasl.gl.drawRectangle
local rawFrame = sasl.gl.drawFrame

pcall(function()
    for _, name in ipairs({"drawText", "drawRectangle", "drawFrame",
                           "drawTriangle", "drawCircle", "drawLine", "drawPolyLine"}) do
        installOpacity(name)
    end
end)

------------------------------------------------------------------------
-- Datarefs
------------------------------------------------------------------------
local airspeedProp = globalPropertyf("sim/cockpit2/gauges/indicators/airspeed_kts_pilot")
local vneProp = globalPropertyf("sim/aircraft/view/acf_Vne")
local vfeProp = globalPropertyf("sim/aircraft/view/acf_Vfe")
local vnoProp = globalPropertyf("sim/aircraft/view/acf_Vno")
local vsoProp = globalPropertyf("sim/aircraft/view/acf_Vso")
local vsProp = globalPropertyf("sim/aircraft/view/acf_Vs")
local vviProp = globalPropertyf("sim/cockpit2/gauges/indicators/vvi_fpm_pilot")
local altitudeAGLProp = globalPropertyf("sim/flightmodel/position/y_agl")
local magHeadingProp = globalPropertyf("sim/flightmodel/position/mag_psi")  -- heading (nose), magnetic
local pitchProp = globalPropertyf("sim/flightmodel/position/theta")  -- pitch: + nose up
local rollProp  = globalPropertyf("sim/flightmodel/position/phi")    -- roll: + right wing down
-- 0 at the main menu (no flight), >0 once a flight has started. A "time"
-- dataref, so reading it is safe before the position is set; update() uses it
-- to flag localState.simStarted and draw() skips entirely until then.
local flightTimeProp = globalPropertyf("sim/time/total_flight_time_sec")
-- Engine power. engine_speed_rpm and N1_percent are ARRAY datarefs; reading them
-- with an index in globalPropertyf returned 0 in this build, so we use the array
-- accessor globalPropertyfa (get -> table, engine 0 = [1]). If that function does
-- not exist, the pcall covers it and we fall back to throttle (scalar, reliable).
local rpmArrProp, n1ArrProp
pcall(function()
    rpmArrProp = globalPropertyfa("sim/cockpit2/engine/indicators/engine_speed_rpm", 8)
    n1ArrProp  = globalPropertyfa("sim/cockpit2/engine/indicators/N1_percent", 8)
end)
-- throttle (0..1, scalar): universal fallback, handy for RC (you set it on the transmitter)
local throttleProp = globalPropertyf("sim/cockpit2/engine/actuators/throttle_ratio_all")
-- engine type (static): 0/1 = piston, 2 = free turbine, 3 = electric, 4+ = jet
local enTypeArr = globalPropertyfa("sim/aircraft/prop/acf_en_type", 8)
-- gear: deployment (0=up,1=down), type (0=no leg) and position of each leg
-- (acf_gear_xnodef/znodef, m) to draw it in its real planform. Flaps 0..1.
local gearArrProp = globalPropertyfa("sim/flightmodel2/gear/deploy_ratio", 10)
local gearTypeArr = globalPropertyfa("sim/aircraft/parts/acf_gear_type", 10)
local gearXArr = globalPropertyfa("sim/aircraft/parts/acf_gear_xnodef", 10)
local gearZArr = globalPropertyfa("sim/aircraft/parts/acf_gear_znodef", 10)
local flapsRatioProp = globalPropertyf("sim/cockpit2/controls/flap_ratio")
-- X-Plane window size (to anchor the HUD full-width at the bottom)
local screenWidthProp = globalPropertyi("sim/graphics/view/window_width")
local screenHeightProp = globalPropertyi("sim/graphics/view/window_height")
-- loaded aircraft identity: to reset the learned state when it changes
local acfIdProp = globalPropertys("sim/aircraft/view/acf_tailnum")

------------------------------------------------------------------------
-- Configurable units (state in localState, toggled with toggleUnits)
--   "metric"   => km/h, m, m/s     (default, RC-oriented)
--   "aviation" => kt, ft, fpm
------------------------------------------------------------------------
local function useMetric()
    return get(localState).units ~= "aviation"
end

local M_TO_FT   = 3.28084
local FPM_TO_MS = 0.00508
local KT_TO_KMH = 1.852

local function speedParts(kts)
    if useMetric() then return kts * KT_TO_KMH, "km/h" else return kts, "kt" end
end

local function aglParts(meters)
    if useMetric() then return meters, "m" else return meters * M_TO_FT, "ft" end
end

local function vsParts(fpm)
    if useMetric() then
        return string.format("%+.1f", fpm * FPM_TO_MS), "m/s"
    else
        return string.format("%+.0f", fpm), "fpm"
    end
end

------------------------------------------------------------------------
-- Readability helpers (outline/halo; SASL has no native text outline)
------------------------------------------------------------------------
local haloColor = {0, 0, 0, 0.55}

local function haloText(font, x, y, text, size, align, color)
    local o = math.max(1.0, size * 0.07)
    sasl.gl.drawText(font, x-o, y,   text, size, false, false, align, haloColor)
    sasl.gl.drawText(font, x+o, y,   text, size, false, false, align, haloColor)
    sasl.gl.drawText(font, x,   y-o, text, size, false, false, align, haloColor)
    sasl.gl.drawText(font, x,   y+o, text, size, false, false, align, haloColor)
    sasl.gl.drawText(font, x-o, y-o, text, size, false, false, align, haloColor)
    sasl.gl.drawText(font, x+o, y-o, text, size, false, false, align, haloColor)
    sasl.gl.drawText(font, x-o, y+o, text, size, false, false, align, haloColor)
    sasl.gl.drawText(font, x+o, y+o, text, size, false, false, align, haloColor)
    sasl.gl.drawText(font, x,   y,   text, size, false, false, align, color)
end

local function haloRect(x, y, w, h, color)
    sasl.gl.drawRectangle(x-1, y-1, w+2, h+2, haloColor)
    sasl.gl.drawRectangle(x, y, w, h, color)
end

------------------------------------------------------------------------
-- Dial / silhouette geometry
------------------------------------------------------------------------
local baseFontSize = 22.0

-- Floor of the piston RPM dial scale (rises only if the engine revs higher).
local RPM_FULL = 3000.0

-- Power dial state (sticky: avoids flicker between sources).
local engHasN1 = false
local rpmMax = 0

-- Point (x,y) on a circle. SASL is y-up: 0deg=right, 90deg=up.
local function polar(cx, cy, r, deg)
    local a = math.rad(deg)
    return cx + r * math.cos(a), cy + r * math.sin(a)
end

-- Filled arc band between radii ri..ro (triangle fan).
local function fillArc(cx, cy, ri, ro, degA, degB, color, steps)
    steps = steps or 24
    local x1i, y1i = polar(cx, cy, ri, degA)
    local x1o, y1o = polar(cx, cy, ro, degA)
    for i = 1, steps do
        local t = degA + (degB - degA) * (i / steps)
        local x2i, y2i = polar(cx, cy, ri, t)
        local x2o, y2o = polar(cx, cy, ro, t)
        sasl.gl.drawTriangle(x1i, y1i, x1o, y1o, x2o, y2o, color)
        sasl.gl.drawTriangle(x1i, y1i, x2o, y2o, x2i, y2i, color)
        x1i, y1i, x1o, y1o = x2i, y2i, x2o, y2o
    end
end

-- Thick ring outline (a filled annulus). drawCircle's outline is only ~1px;
-- for crisper instrument bezels we fill the band R-th/2 .. R+th/2 via fillArc.
local function drawRing(cx, cy, R, th, color, steps)
    fillArc(cx, cy, R - th * 0.5, R + th * 0.5, 0, 360, color, steps or 48)
end

-- The dial sweeps 240deg: from 210deg (bottom-left) to -30deg (bottom-right), gap at the bottom.
local GAUGE_LO, GAUGE_HI = 210.0, -30.0
local function gaugeAngle(frac)
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    return GAUGE_LO + (GAUGE_HI - GAUGE_LO) * frac
end

local function drawDial(cx, cy, R, bands, frac, valueText, unitText, label, needleColor, labelY)
    sasl.gl.drawCircle(cx, cy, R, true, {0, 0, 0, 0.35})
    for _, b in ipairs(bands) do
        fillArc(cx, cy, R - 9, R - 3, gaugeAngle(b[1]), gaugeAngle(b[2]), b[3], 18)
    end
    drawRing(cx, cy, R, 2.0, white)
    for i = 0, 4 do
        local a = gaugeAngle(i / 4)
        local x1, y1 = polar(cx, cy, R - 11, a)
        local x2, y2 = polar(cx, cy, R - 2, a)
        sasl.gl.drawLine(x1, y1, x2, y2, white)
    end
    local a = gaugeAngle(frac)
    local tipx, tipy = polar(cx, cy, R - 13, a)
    local lx, ly = polar(cx, cy, 4, a + 90)
    local rx, ry = polar(cx, cy, 4, a - 90)
    sasl.gl.drawTriangle(tipx, tipy, lx, ly, rx, ry, needleColor)
    sasl.gl.drawCircle(cx, cy, 5, true, lightGrey)
    haloText(sourceCodePro, cx, cy - R * 0.45, valueText, baseFontSize, TEXT_ALIGN_CENTER, needleColor)
    haloText(sourceCodePro, cx, cy - R * 0.45 - 15, unitText, baseFontSize * 0.55, TEXT_ALIGN_CENTER, lightGrey)
    haloText(sourceCodePro, cx, labelY, label, baseFontSize * 0.7, TEXT_ALIGN_CENTER, white)
end

-- Top-down aircraft silhouette, nose toward +y. Draws halo + fill.
local function drawPlaneTop(s, color)
    local function body(k, col)
        sasl.gl.drawTriangle(0, k*1.05, -k*0.18, k*0.45, k*0.18, k*0.45, col)  -- nose
        sasl.gl.drawRectangle(-k*0.09, -k*0.72, k*0.18, k*1.28, col)           -- fuselage
        sasl.gl.drawRectangle(-k*0.74, -k*0.04, k*1.48, k*0.18, col)           -- wings
        sasl.gl.drawRectangle(-k*0.30, -k*0.64, k*0.60, k*0.14, col)           -- tail
    end
    body(s * 1.16, haloColor)
    body(s, color)
end

-- First element of an array property (engine 0); 0 if missing / not a number.
local function arr1(prop)
    if prop == nil then return 0 end
    local t = get(prop)
    if type(t) == "table" then return tonumber(t[1]) or 0 end
    return tonumber(t) or 0
end

-- Gear indicator wheel: tyre in the state color + rim + hub.
local function gearWheel(x, y, r, color)
    sasl.gl.drawCircle(x, y, r + 1.5, true, haloColor)
    sasl.gl.drawCircle(x, y, r, true, color)
    drawRing(x, y, r, 1.6, white, 22)
    sasl.gl.drawCircle(x, y, r * 0.4, true, {0, 0, 0, 0.5})
end

-- Gear color by deployment: green down / amber in transit / dim grey up.
local function gearStateColor(r)
    if r >= 0.99 then return green                        -- down and locked
    elseif r <= 0.01 then return {0.40, 0.40, 0.40, 1.0}  -- retracted: dimmed
    else return orange end                                -- in transit
end

-- Learned gear state: a leg is "retractable" if its deployment travels a range
-- (>0.2). A leg that never moves while the rest do = fixed gear (e.g. a
-- tailwheel); it is drawn as structure, not as a status light.
local gearMin, gearMax, gearRetract = {}, {}, {}
local gearSystemMoved = false

-- Structural wheel (fixed gear): faint hollow ring, no color "light".
local function drawFixedWheel(x, y, r)
    sasl.gl.drawCircle(x, y, r + 1.5, true, haloColor)
    drawRing(x, y, r, 1.6, {0.75, 0.75, 0.75, 0.9}, 22)
    sasl.gl.drawCircle(x, y, r * 0.35, true, {0.75, 0.75, 0.75, 0.7})
end

------------------------------------------------------------------------
-- Window fit: full screen width, anchored at the bottom
------------------------------------------------------------------------
local fittedOnce = false
local lastScreenW, lastScreenH = 0, 0
local lastAcf = nil

function update()
    -- A flight is "started" once total_flight_time_sec > 0; at the main menu it is
    -- 0 and the aircraft position is unset. Share it via localState so draw() can
    -- gate on it without adding an upvalue (draw() already references localState).
    get(localState).simStarted = (get(flightTimeProp) or 0) > 0
    -- when the aircraft changes, reset the learned state (do not carry over from
    -- the previous one: RPM scale, N1 detection and everything learned about the gear)
    local acf = get(acfIdProp)
    if acf ~= lastAcf then
        lastAcf = acf
        rpmMax, engHasN1 = 0, false
        gearMin, gearMax, gearRetract, gearSystemMoved = {}, {}, {}, false
    end
    local win = get(localState).contextWindow
    if win == nil then return end
    local sw = get(screenWidthProp)
    local sh = get(screenHeightProp)
    if sw <= 0 or sh <= 0 then return end
    if (not fittedOnce) or sw ~= lastScreenW or sh ~= lastScreenH then
        local LW = get(localState).windowWidth
        local LH = get(localState).windowHeight
        local winW = sw
        local winH = winW * LH / LW
        local maxH = sh * 0.45
        if winH > maxH then
            winH = maxH
            winW = winH * LW / LH
        end
        local winX = math.floor((sw - winW) / 2)
        local winY = 0
        win:setPosition(winX, winY, math.floor(winW), math.floor(winH))
        fittedOnce = true
        lastScreenW, lastScreenH = sw, sh
    end
end

------------------------------------------------------------------------
-- HUD drawing
------------------------------------------------------------------------
function draw()
    -- Until a flight has started the aircraft position is unset; reading position
    -- datarefs then makes SASL flood the log with "Sim is not yet started -
    -- Position is unset". Nothing to show at the main menu anyway, so skip it all.
    if not get(localState).simStarted then return end
    --------------------------------------------------------------------
    -- Instrument cluster layout (logical px, y-up in the 1600x270 canvas).
    -- Declared as LOCALS here (not file-level upvalues) so draw() stays under
    -- Lua's 60-upvalue limit. The AGL tape on the far left is separate (tapeX
    -- below); these six instruments are packed toward the left so the HUD stays
    -- compact, leaving the right of the strip clear (future map panel). Tune
    -- sizes and spacing HERE.
    --------------------------------------------------------------------
    local ROW_CY   = 112    -- shared vertical center: SPEED / ADI / POWER / HEADING / GEAR
    local LABEL_Y  = 34     -- shared baseline for the bottom labels (SPEED, ATTITUDE, ...)
    local DIAL_R   = 56     -- speed & power dial radius
    local ADI_R    = 58     -- attitude indicator radius
    local COMP_R   = 50     -- compass radius
    local CX_SPEED, CX_ADI, CX_POWER = 360, 515, 670   -- 360 = anchored next to the AGL tape
    local CX_HEADING, CX_GEAR, CX_FLAPS = 825, 965, 1070

    -- pick up the live HUD opacity (menu / command); the wrappers above fade
    -- every primitive by this factor. Clamp and default to fully opaque.
    local op = get(localState).opacity
    hudOpacity = (type(op) == "number") and math.max(0, math.min(1, op)) or 1.0

    --------------------------------------------------------------------
    -- Optional backing panel (behind everything). Independent opacity; 0 = off.
    -- Inset by a small margin with a subtle border; drawn with the raw
    -- primitives so it is NOT dimmed by hudOpacity (alpha = bgOpacity).
    --------------------------------------------------------------------
    local bg = get(localState).bgOpacity
    if type(bg) == "number" and bg > 0.001 then
        local pw = get(localState).windowWidth  - 2 * BG_MARGIN_X
        local ph = get(localState).windowHeight - 2 * BG_MARGIN_Y
        rawRect(BG_MARGIN_X, BG_MARGIN_Y, pw, ph, {BG_COLOR[1],  BG_COLOR[2],  BG_COLOR[3],  bg})
        rawFrame(BG_MARGIN_X, BG_MARGIN_Y, pw, ph, {BG_BORDER[1], BG_BORDER[2], BG_BORDER[3], bg})
    end

    --------------------------------------------------------------------
    -- AGL height (vertical tape, left) + VSI
    --------------------------------------------------------------------
    local tapeX, tapeCY, tapeHalf = 120, 135, 92
    local aglM = get(altitudeAGLProp)
    if aglM < 0 then aglM = 0 end
    local aglDisp, aglUnit = aglParts(aglM)
    local tickInc   = useMetric() and 10 or 50
    local pxPerUnit = useMetric() and 1.7 or 0.55
    local baseTick = math.floor(aglDisp / tickInc) * tickInc
    for i = -8, 8 do
        local tv = baseTick + i * tickInc
        if tv >= 0 then
            local ty = tapeCY + (tv - aglDisp) * pxPerUnit
            if math.abs(ty - tapeCY) <= tapeHalf then
                local fade = 1 - (math.abs(ty - tapeCY) / tapeHalf) * 0.6
                haloRect(tapeX - 24, ty, 14, 2, {1, 1, 1, fade})
                haloText(sourceCodePro, tapeX - 30, ty - 7,
                         string.format("%.0f", tv), baseFontSize * 0.55, TEXT_ALIGN_RIGHT, {1, 1, 1, fade})
            end
        end
    end
    local groundY = tapeCY + (0 - aglDisp) * pxPerUnit
    if groundY >= tapeCY - tapeHalf and groundY <= tapeCY + tapeHalf then
        haloRect(tapeX - 26, groundY - 1, 28, 3, green)
    end
    local bw, bh = 70, 24
    sasl.gl.drawRectangle(tapeX - 6, tapeCY - bh / 2, bw, bh, background)
    sasl.gl.drawFrame(tapeX - 6, tapeCY - bh / 2, bw, bh, white)
    sasl.gl.drawFrame(tapeX - 7, tapeCY - bh / 2 - 1, bw + 2, bh + 2, white)
    haloText(sourceCodePro, tapeX, tapeCY - 5,
             string.format("%.0f %s", aglDisp, aglUnit), baseFontSize * 0.65, TEXT_ALIGN_LEFT, white)
    haloText(sourceCodePro, tapeX - 8, tapeCY + tapeHalf + 10, "AGL", baseFontSize * 0.7, TEXT_ALIGN_CENTER, lightGrey)
    -- VSI (side needle)
    local vviX = tapeX + 84
    local vviY = tapeCY + get(vviProp) * 0.013
    local vviColor = white
    if vviY < tapeCY - tapeHalf then
        vviY = tapeCY - tapeHalf; vviColor = orange
    elseif vviY > tapeCY + tapeHalf then
        vviY = tapeCY + tapeHalf; vviColor = orange
    end
    haloRect(vviX, tapeCY - tapeHalf, 2, 2 * tapeHalf, white)
    sasl.gl.drawPolyLine({vviX, vviY,
                          vviX + 10, vviY + 7, vviX + 50, vviY + 7, vviX + 50, vviY - 7, vviX + 10, vviY - 7,
                          vviX, vviY}, vviColor)
    local vsStr, vsUnit = vsParts(get(vviProp))
    haloText(sourceCodePro, vviX + 14, vviY - 4, vsStr .. " " .. vsUnit, baseFontSize * 0.55, TEXT_ALIGN_LEFT, vviColor)

    --------------------------------------------------------------------
    -- Airspeed (circular dial)
    --------------------------------------------------------------------
    local spdKt = get(airspeedProp)
    local vne, vno, vso, vs = get(vneProp), get(vnoProp), get(vsoProp), get(vsProp)
    local minA, maxA, spdBands
    if vne and vne > 0 then
        minA = 0
        maxA = vne * 1.15
        local vnoB    = (vno and vno > 0) and vno or vne * 0.85
        local greenLo = (vso and vso > 0) and vso or ((vs and vs > 0) and vs or maxA * 0.18)
        local function fr(v) return (v - minA) / (maxA - minA) end
        spdBands = {
            { fr(greenLo), fr(vnoB), green },
            { fr(vnoB),    fr(vne),  yellow },
            { fr(vne),     1.0,      red },
        }
    else
        minA, maxA = 0, math.max(spdKt * 1.3, 50)
        spdBands = {}
    end
    local spdFrac = (spdKt - minA) / (maxA - minA)
    local spdColor = (spdKt > maxA) and orange or white
    local spdDisp, spdUnit = speedParts(spdKt)
    drawDial(CX_SPEED, ROW_CY, DIAL_R, spdBands, spdFrac, string.format("%.0f", spdDisp), spdUnit, "SPEED", spdColor, LABEL_Y)

    --------------------------------------------------------------------
    -- Attitude (ADI): disc with blue sky / brown ground
    --------------------------------------------------------------------
    local adiX, adiY, adiR = CX_ADI, ROW_CY, ADI_R
    local pitch = get(pitchProp)
    local roll  = get(rollProp)
    local pxPerDeg = adiR / 25
    local po = -pitch * pxPerDeg
    local skyColor    = {0.20, 0.52, 0.82, 0.95}
    local groundColor = {0.50, 0.36, 0.20, 0.95}
    local horizonTh   = 0.02 * adiR

    sasl.gl.saveGraphicsContext()
    sasl.gl.setTranslateTransform(adiX, adiY)
    sasl.gl.setRotateTransform(-roll)
    sasl.gl.drawCircle(0, 0, adiR, true, skyColor)
    if po <= -adiR then
        sasl.gl.drawCircle(0, 0, adiR, true, groundColor)
    elseif po < adiR then
        local as = math.asin(po / adiR)
        local a0 = math.pi - as
        local a1 = 2 * math.pi + as
        local xc = adiR * math.cos(as)
        local steps = 22
        local lx, ly = -xc, po
        local pX, pY = lx, ly
        for i = 1, steps do
            local t  = a0 + (a1 - a0) * (i / steps)
            local nx = adiR * math.cos(t)
            local ny = adiR * math.sin(t)
            sasl.gl.drawTriangle(lx, ly, pX, pY, nx, ny, groundColor)
            pX, pY = nx, ny
        end
        sasl.gl.drawRectangle(-xc, po - horizonTh / 2, 2 * xc, horizonTh, white)
    end
    for _, a in ipairs({-20, -10, 10, 20}) do
        local ry = po + a * pxPerDeg
        if math.abs(ry) < adiR - 0.25 * adiR then
            local w = (a % 20 == 0) and (0.45 * adiR) or (0.25 * adiR)
            sasl.gl.drawRectangle(-w / 2, ry - 0.01 * adiR, w, 0.02 * adiR, white)
        end
    end
    sasl.gl.restoreGraphicsContext()

    drawRing(adiX, adiY, adiR, 2.0, white)
    local wingW, wingTh = 0.25 * adiR, 0.05 * adiR
    haloRect(adiX - 0.40 * adiR, adiY - wingTh / 2, wingW, wingTh, yellow)
    haloRect(adiX + 0.15 * adiR, adiY - wingTh / 2, wingW, wingTh, yellow)
    haloRect(adiX - 0.037 * adiR, adiY - 0.037 * adiR, 0.075 * adiR, 0.075 * adiR, yellow)
    sasl.gl.drawTriangle(adiX, adiY + adiR - 0.025 * adiR,
                         adiX - 0.12 * adiR, adiY + adiR + 0.17 * adiR,
                         adiX + 0.12 * adiR, adiY + adiR + 0.17 * adiR, white)
    haloText(sourceCodePro, adiX, LABEL_Y, "ATTITUDE", baseFontSize * 0.7, TEXT_ALIGN_CENTER, white)

    --------------------------------------------------------------------
    -- RPM / power (circular dial)
    -- Pistons: RPM (RPM_FULL scale). Jets/turbofan: %N1 (dynamic label).
    --------------------------------------------------------------------
    local rpmBands = {
        { 0.0,  0.80, green },
        { 0.80, 0.93, yellow },
        { 0.93, 1.0,  red },
    }
    -- Power source by preference (the label shows which one is live):
    --   piston RPM  ->  turbine %N1  ->  % throttle (always available)
    -- The reading is chosen by engine TYPE (not by instantaneous value): no flicker.
    --   piston -> RPM (auto scale) | jet/turbine -> %N1 if present, else THR | electric -> THR
    local enType  = math.floor(arr1(enTypeArr) + 0.5)
    local isRecip = (enType == 0 or enType == 1)
    local rpm = arr1(rpmArrProp)
    local n1  = arr1(n1ArrProp)
    if rpm > rpmMax then rpmMax = rpm end
    if n1 > 1 then engHasN1 = true end           -- sticky: once it has N1, never falls back to THR
    local powFrac, powVal, powLabel, powUnit
    if isRecip then
        local full = math.max(RPM_FULL, rpmMax)
        powFrac, powVal, powLabel, powUnit = rpm / full, string.format("%.0f", rpm), "RPM", "rpm"
    elseif engHasN1 then
        powFrac, powVal, powLabel, powUnit = n1 / 100, string.format("%.0f", n1), "N1", "%"
    else
        local thr = get(throttleProp) or 0
        powFrac, powVal, powLabel, powUnit = thr, string.format("%.0f", thr * 100), "THR", "%"
    end
    drawDial(CX_POWER, ROW_CY, DIAL_R, rpmBands, powFrac, powVal, powUnit, powLabel, white, LABEL_Y)

    --------------------------------------------------------------------
    -- NORTH-UP compass with an aircraft silhouette that rotates to heading
    --------------------------------------------------------------------
    local compX, compCY, compR = CX_HEADING, ROW_CY, COMP_R
    local heading = get(magHeadingProp)
    -- heading box on top
    local hbW, hbH = 70, 26
    sasl.gl.drawRectangle(compX - hbW / 2, compCY + compR + 8, hbW, hbH, background)
    sasl.gl.drawFrame(compX - hbW / 2, compCY + compR + 8, hbW, hbH, white)
    sasl.gl.drawFrame(compX - hbW / 2 - 1, compCY + compR + 7, hbW + 2, hbH + 2, white)
    haloText(sourceCodePro, compX, compCY + compR + 15, string.format("%.0f", heading) .. "\194\176",
             baseFontSize * 0.75, TEXT_ALIGN_CENTER, white)
    sasl.gl.drawTriangle(compX, compCY + compR, compX - 6, compCY + compR + 8, compX + 6, compCY + compR + 8, white)
    -- FIXED rose (north up): ring + ticks every 30deg
    drawRing(compX, compCY, compR, 2.0, white)
    for i = 0, 11 do
        local ang = 90 - i * 30
        local rIn = (i % 3 == 0) and compR * 0.76 or compR * 0.84
        local x1, y1 = polar(compX, compCY, rIn, ang)
        local x2, y2 = polar(compX, compCY, compR * 0.97, ang)
        sasl.gl.drawLine(x1, y1, x2, y2, white)
    end
    haloText(sourceCodePro, compX,                 compCY + compR * 0.64 - 8, "N", baseFontSize * 0.65, TEXT_ALIGN_CENTER, white)
    haloText(sourceCodePro, compX,                 compCY - compR * 0.64 - 8, "S", baseFontSize * 0.6,  TEXT_ALIGN_CENTER, lightGrey)
    haloText(sourceCodePro, compX + compR * 0.64,  compCY - 8,                "E", baseFontSize * 0.6,  TEXT_ALIGN_CENTER, lightGrey)
    haloText(sourceCodePro, compX - compR * 0.64,  compCY - 8,                "W", baseFontSize * 0.6,  TEXT_ALIGN_CENTER, lightGrey)
    -- aircraft silhouette: rotates with heading (model heading-up, north fixed)
    sasl.gl.saveGraphicsContext()
    sasl.gl.setTranslateTransform(compX, compCY)
    sasl.gl.setRotateTransform(heading)   -- visual +CW: nose to heading (north fixed)
    drawPlaneTop(compR * 0.5, yellow)
    sasl.gl.restoreGraphicsContext()
    haloText(sourceCodePro, compX, LABEL_Y, "HEADING", baseFontSize * 0.7, TEXT_ALIGN_CENTER, white)

    --------------------------------------------------------------------
    -- Landing gear: wheels in their real planform (tricycle, tailwheel,
    -- multi-wheel...) colored by deploy_ratio. Positions from
    -- acf_gear_xnodef/znodef; with no data, falls back to a row of wheels.
    --------------------------------------------------------------------
    local gearCX, gearCY = CX_GEAR, ROW_CY
    local typeT, xT, zT, depT = get(gearTypeArr), get(gearXArr), get(gearZArr), get(gearArrProp)
    local function elem(t, i) if type(t) == "table" then return tonumber(t[i]) or 0 else return 0 end end
    local gears = {}
    for i = 1, 10 do
        if elem(typeT, i) ~= 0 then
            gears[#gears + 1] = { i = i, x = elem(xT, i), z = elem(zT, i), d = elem(depT, i) }
        end
    end
    if #gears == 0 then                                   -- fallback: deploy_ratio[1..3] in a row
        for i = 1, 3 do gears[#gears + 1] = { i = i, x = (i - 2), z = 0, d = elem(depT, i) } end
    end
    -- center the group and normalize each axis separately: good spacing always,
    -- preserving the real orientation (left/right and nose/tail).
    local n = #gears
    local mx, mz = 0, 0
    for _, g in ipairs(gears) do mx, mz = mx + g.x, mz + g.z end
    mx, mz = mx / n, mz / n
    local dX, dZ = 0.0001, 0.0001
    for _, g in ipairs(gears) do
        dX = math.max(dX, math.abs(g.x - mx))
        dZ = math.max(dZ, math.abs(g.z - mz))
    end
    local halfW, halfH = 22, 18
    local allDown, anyTransit = true, false
    for _, g in ipairs(gears) do
        g.sx = gearCX + ((g.x - mx) / dX) * halfW
        g.sy = gearCY - ((g.z - mz) / dZ) * halfH         -- +z (tail) down, nose up
        -- learn whether this leg is retractable (its deployment travels a range)
        local lo = gearMin[g.i]; if lo == nil or g.d < lo then lo = g.d end; gearMin[g.i] = lo
        local hi = gearMax[g.i]; if hi == nil or g.d > hi then hi = g.d end; gearMax[g.i] = hi
        if hi - lo > 0.2 then gearRetract[g.i] = true; gearSystemMoved = true end
        if g.d < 0.99 then allDown = false end
        if g.d > 0.02 and g.d < 0.98 then anyTransit = true end
    end
    for _, g in ipairs(gears) do sasl.gl.drawWideLine(gearCX, gearCY, g.sx, g.sy, 2.0, lightGrey) end
    for _, g in ipairs(gears) do
        if gearSystemMoved and not gearRetract[g.i] and g.d >= 0.99 then
            drawFixedWheel(g.sx, g.sy, 8)                  -- fixed leg (not a status light)
        else
            gearWheel(g.sx, g.sy, 8, gearStateColor(g.d))
        end
    end
    local stTxt, stCol
    if anyTransit then stTxt, stCol = "TRANS", orange
    elseif allDown then stTxt, stCol = "DOWN", green
    else stTxt, stCol = "UP", lightGrey end
    haloText(sourceCodePro, gearCX, gearCY - 40, stTxt, baseFontSize * 0.6, TEXT_ALIGN_CENTER, stCol)
    haloText(sourceCodePro, gearCX, LABEL_Y, "GEAR", baseFontSize * 0.7, TEXT_ALIGN_CENTER, white)

    --------------------------------------------------------------------
    -- Flaps (vertical bar: UP top .. FULL bottom)
    --------------------------------------------------------------------
    local flapsX, flTop, flBot = CX_FLAPS, 148, 76
    local flH = flTop - flBot
    local flap = get(flapsRatioProp) or 0
    if flap < 0 then flap = 0 elseif flap > 1 then flap = 1 end
    local markerY = flTop - flap * flH
    sasl.gl.drawRectangle(flapsX - 7, flBot, 14, flH, background)
    sasl.gl.drawRectangle(flapsX - 7, markerY, 14, flTop - markerY, {0.9, 0.9, 0.2, 0.35})
    sasl.gl.drawFrame(flapsX - 7, flBot, 14, flH, white)
    sasl.gl.drawFrame(flapsX - 8, flBot - 1, 16, flH + 2, white)
    haloRect(flapsX - 11, markerY - 2, 22, 4, yellow)
    haloText(sourceCodePro, flapsX, flTop + 8, string.format("%.0f%%", flap * 100), baseFontSize * 0.6, TEXT_ALIGN_CENTER, white)
    haloText(sourceCodePro, flapsX, LABEL_Y, "FLAPS", baseFontSize * 0.7, TEXT_ALIGN_CENTER, white)
end
