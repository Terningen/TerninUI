--[[
    TerninUI - Bars
    Bar container, layout, and resource updates.
]]

local ADDON_NAME, ns = ...
local PLAYER_UNIT = ns.PLAYER_UNIT
local DEFAULT_CONFIG = ns.DEFAULT_CONFIG

-- ---------------------------------------------------------------------------
-- Power type mapping (resource name -> WoW power type enum)
-- ---------------------------------------------------------------------------

-- Bar style -> texture path (built-in WoW textures)
-- ElvUI: flat like real ElvUI's "ElvUI Norm" (no gradient, minimal)
local BAR_STYLE_TEXTURES = {
    plain     = "Interface\\Buttons\\WHITE8x8",
    blizzard  = "Interface\\TARGETINGFRAME\\UI-StatusBar",
    elvui     = "Interface\\Buttons\\WHITE8x8",  -- Flat, minimal - matches ElvUI's default style
}

local function GetBarTexture()
    local c = ns.GetConfig()
    local style = (c and c.barStyle) or "plain"
    return BAR_STYLE_TEXTURES[style] or BAR_STYLE_TEXTURES.plain
end

-- Apply gradient to status bar texture. Works with any base texture.
-- Radial: simulated with overlay textures (center bright, edges dark) - WoW has no native radial API.
local function ApplyBarGradient(bar, r, g, b, a)
    local tex = bar:GetStatusBarTexture()
    if not tex or not tex.SetGradient then return end

    local c = ns.GetConfig()
    local mode = (c and c.gradientMode) or "none"
    local intensity = (c and c.gradientIntensity) or 30
    intensity = math.max(0, math.min(100, intensity)) / 100

    r, g, b, a = r or 1, g or 1, b or 1, a or 1
    local c = CreateColor(r, g, b, a)

    -- Radial overlays: show/hide based on mode
    if bar.radialLeft then
        bar.radialLeft:Hide()
    end
    if bar.radialRight then
        bar.radialRight:Hide()
    end

    if mode == "none" or intensity <= 0 then
        tex:SetGradient("VERTICAL", c, c)
        return
    end

    if mode == "radial" then
        -- Simulate radial: dark overlay at edges, transparent at center (center appears brighter)
        tex:SetGradient("VERTICAL", c, c)
        local edgeAlpha = intensity * 0.7
        if bar.radialLeft and bar.radialRight then
            bar.radialLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
            bar.radialLeft:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, edgeAlpha), CreateColor(0, 0, 0, 0))
            bar.radialRight:SetTexture("Interface\\Buttons\\WHITE8x8")
            bar.radialRight:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, edgeAlpha))
            bar.radialLeft:Show()
            bar.radialRight:Show()
        end
        return
    end

    local darken = 1 - intensity
    local lighten = 1 + (intensity * 0.5)
    local r1, g1, b1 = r * darken, g * darken, b * darken
    local r2, g2, b2 = math.min(1, r * lighten), math.min(1, g * lighten), math.min(1, b * lighten)

    if mode == "vertical" then
        tex:SetGradient("VERTICAL", CreateColor(r1, g1, b1, a), CreateColor(r2, g2, b2, a))
    elseif mode == "horizontal" then
        tex:SetGradient("HORIZONTAL", CreateColor(r1, g1, b1, a), CreateColor(r2, g2, b2, a))
    else
        tex:SetGradient("VERTICAL", c, c)
    end
end

local POWER_TYPES = {
    rage        = (Enum and Enum.PowerType and Enum.PowerType.Rage)       or 1,
    mana        = (Enum and Enum.PowerType and Enum.PowerType.Mana)       or 0,
    energy      = (Enum and Enum.PowerType and Enum.PowerType.Energy)     or 3,
    focus       = (Enum and Enum.PowerType and Enum.PowerType.Focus)     or 2,
    runic_power = (Enum and Enum.PowerType and Enum.PowerType.RunicPower) or 6,
}

local function GetPowerTypeForResource(resource)
    return resource and POWER_TYPES[resource]
end

-- ---------------------------------------------------------------------------
-- Bar container
-- ---------------------------------------------------------------------------

local container = CreateFrame("Frame", "TerninUI_Container", UIParent)
container:SetSize(150, 10)
ns.container = container

local function ApplyContainerPosition()
    container:ClearAllPoints()
    local c = ns.GetConfig()
    local pos = (c and c.position) or DEFAULT_CONFIG.position
    container:SetPoint(
        pos.point or "CENTER",
        UIParent,
        pos.relativePoint or pos.point or "CENTER",
        pos.x or 0,
        pos.y or -100
    )
end
ns.ApplyContainerPosition = ApplyContainerPosition

ApplyContainerPosition()

local function SaveContainerPosition()
    local point, _, relativePoint, x, y = container:GetPoint()
    local c = ns.GetConfig()
    if c then
            c.position = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
end

local barFrames = {}
ns.barFrames = barFrames

-- Recursively enable/disable mouse on frame and all descendants (StatusBar etc. enable mouse by default)
local function SetFrameTreeMouseEnabled(frame, enabled)
    if not frame then return end
    if frame.EnableMouse then
        frame:EnableMouse(enabled)
    end
    if frame.GetChildren then
        for _, child in ipairs({frame:GetChildren()}) do
            SetFrameTreeMouseEnabled(child, enabled)
        end
    end
end

function ns.ApplyLockState()
    local c = ns.GetConfig()
    local locked = c and c.locked
    if locked then
        -- Combine multiple approaches (other addons use EnableMouse + HitRectInsets):
        -- 1. EnableMouse(false) on container + all descendants (StatusBar enables mouse by default)
        SetFrameTreeMouseEnabled(container, false)
        -- 2. Shrink hit rect to zero so frame is never "under" cursor (prevents blocking)
        container:SetHitRectInsets(10000, 10000, 10000, 10000)
        for _, bar in ipairs(barFrames) do
            bar:SetHitRectInsets(10000, 10000, 10000, 10000)
        end
        -- 3. Lower strata so we're behind other UI (backup)
        container:SetFrameStrata("BACKGROUND")
        container:SetFrameLevel(0)
    else
        container:SetFrameStrata("MEDIUM")
        container:SetFrameLevel(1)
        -- Container receives drag; bars pass clicks through so container gets them
        container:EnableMouse(true)
        for _, bar in ipairs(barFrames) do
            bar:EnableMouse(false)
            bar:SetHitRectInsets(0, 0, 0, 0)
        end
        -- Expand container hit area when unlocked so bars are easier to grab
        container:SetHitRectInsets(-25, -25, -25, -25)
    end
end

container:SetMovable(true)
container:RegisterForDrag("LeftButton")
container:SetScript("OnDragStart", function(self)
    local c = ns.GetConfig()
    if c and not c.locked then
        self:StartMoving()
    end
end)
container:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    C_Timer.After(0, SaveContainerPosition)
end)

-- ---------------------------------------------------------------------------
-- Bar layout and creation
-- ---------------------------------------------------------------------------

function ns.LayoutBars()
    local c = ns.GetConfig()
    if not c then return end
    local maxWidth = 0

    local totalHeight = 0
    local previousBar

    for i, bar in ipairs(barFrames) do
        local def = (c.bars and c.bars[i]) or bar.def
        if def and def.enabled ~= false then
            local h = def.height or 18
            local w = def.width or 150
            if w > maxWidth then maxWidth = w end

            bar:Show()
            bar:ClearAllPoints()
            bar:SetSize(w, h)

            bar:SetStatusBarTexture(GetBarTexture())
            local bc = def.color or DEFAULT_CONFIG.bars[i] and DEFAULT_CONFIG.bars[i].color or {1, 1, 1, 1}
            bar:SetStatusBarColor(bc[1] or 1, bc[2] or 1, bc[3] or 1, bc[4] or 1)
            ApplyBarGradient(bar, bc[1], bc[2], bc[3], bc[4])

            local pct = 0
            if def.markerEnabled and def.type == "resource" and i == 2 then
                local val = def.markerValue or def.markerPercent or 0
                local powerType = GetPowerTypeForResource(def.resource)
                local maxVal = powerType and UnitPowerMax(PLAYER_UNIT, powerType) or 100
                if maxVal and maxVal > 0 and val > 0 then
                    pct = (val / maxVal) * 100
                end
            end
            if pct > 0 and pct < 100 and bar.marker then
                local mc = def.markerColor or DEFAULT_CONFIG.bars[2].markerColor or {1, 1, 1, 0.9}
                bar.marker:SetColorTexture(mc[1] or 1, mc[2] or 1, mc[3] or 1, mc[4] or 0.9)
                local markerH = math.max(2, h - 4)
                bar.marker:SetSize(2, markerH)
                bar.marker:ClearAllPoints()
                bar.marker:SetPoint("CENTER", bar, "LEFT", (pct / 100) * w, 0)
                bar.marker:Show()
            elseif bar.marker then
                bar.marker:Hide()
            end

            local bg = def.bgColor or {0, 0, 0, 1}
            local alpha = (def.bgAlpha ~= nil) and (def.bgAlpha / 100) or 0
            bar.bg:SetColorTexture(bg[1] or 0, bg[2] or 0, bg[3] or 0, alpha)

            if not previousBar then
                bar:SetPoint("TOP", container, "TOP", 0, 0)
                totalHeight = h
            else
                bar:SetPoint("TOP", previousBar, "BOTTOM", 0, -(c.barSpacing or DEFAULT_CONFIG.barSpacing))
                totalHeight = totalHeight + (c.barSpacing or DEFAULT_CONFIG.barSpacing) + h
            end

            previousBar = bar
        else
            bar:Hide()
        end
    end

    if maxWidth > 0 then
        container:SetWidth(maxWidth)
    end
    if totalHeight <= 0 then
        totalHeight = 10
    end
    container:SetHeight(totalHeight)
end

local function CreateBars()
    for _, bar in ipairs(barFrames) do
        bar:Hide()
    end
    wipe(barFrames)

    local cfg = ns.GetConfig()
    for _, def in ipairs((cfg and cfg.bars) or {}) do
        local bar = CreateFrame("StatusBar", "TerninUI_Bar_" .. (def.id or ""), container)
        bar:SetStatusBarTexture(GetBarTexture())

        local c = def.color or DEFAULT_CONFIG.bars[1].color
        bar:SetStatusBarColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)

        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints(true)
        local bg = def.bgColor or {0, 0, 0, 1}
        local alpha = (def.bgAlpha ~= nil) and (def.bgAlpha / 100) or 0
        bar.bg:SetColorTexture(bg[1] or 0, bg[2] or 0, bg[3] or 0, alpha)

        bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bar.text:SetPoint("CENTER", bar, "CENTER")
        bar.textLeft = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bar.textLeft:SetPoint("LEFT", bar, "LEFT", 4, 0)
        bar.textRight = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bar.textRight:SetPoint("RIGHT", bar, "RIGHT", -4, 0)

        bar.marker = bar:CreateTexture(nil, "OVERLAY")
        bar.marker:SetColorTexture(1, 1, 1, 0.9)
        bar.marker:SetSize(2, 1)
        bar.marker:Hide()

        -- Radial gradient overlays (left/right halves, center bright)
        bar.radialLeft = bar:CreateTexture(nil, "OVERLAY")
        bar.radialLeft:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        bar.radialLeft:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
        bar.radialLeft:SetPoint("RIGHT", bar, "CENTER", 0, 0)
        bar.radialLeft:Hide()
        bar.radialRight = bar:CreateTexture(nil, "OVERLAY")
        bar.radialRight:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
        bar.radialRight:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        bar.radialRight:SetPoint("LEFT", bar, "CENTER", 0, 0)
        bar.radialRight:Hide()

        bar.def = def
        table.insert(barFrames, bar)
    end

    ns.LayoutBars()
end

CreateBars()
ns.ApplyLockState()

-- ---------------------------------------------------------------------------
-- Resource bar updates
-- ---------------------------------------------------------------------------

local function UpdateResourceBar(bar, def)
    local cur, max

    local powerType = GetPowerTypeForResource(def.resource)
    if def.resource == "health" then
        cur = UnitHealth(PLAYER_UNIT)
        max = UnitHealthMax(PLAYER_UNIT)
    elseif powerType then
        cur = UnitPower(PLAYER_UNIT, powerType)
        max = UnitPowerMax(PLAYER_UNIT, powerType)
    elseif def.resource == "absorb" then
        cur = UnitGetTotalAbsorbs(PLAYER_UNIT) or 0
        local pct = (def.absorbMaxPercent or 30) / 100
        max = (UnitHealthMax(PLAYER_UNIT) or 1) * pct
    else
        return
    end

    if not cur then cur = 0 end
    if not max or max == 0 then max = 1 end

    bar:SetMinMaxValues(0, max)
    bar:SetValue(cur)

    if bar.marker and def.markerEnabled and (def.markerValue or def.markerPercent or 0) > 0 then
        local val = def.markerValue or def.markerPercent or 0
        local pct = (val / max) * 100
        if pct > 0 and pct < 100 then
            local w = def.width or 150
            local h = def.height or 18
            local mc = def.markerColor or DEFAULT_CONFIG.bars[2].markerColor or {1, 1, 1, 0.9}
            bar.marker:SetColorTexture(mc[1] or 1, mc[2] or 1, mc[3] or 1, mc[4] or 0.9)
            bar.marker:SetSize(2, math.max(2, h - 4))
            bar.marker:ClearAllPoints()
            bar.marker:SetPoint("CENTER", bar, "LEFT", (pct / 100) * w, 0)
            bar.marker:Show()
        else
            bar.marker:Hide()
        end
    end

    bar.text:SetText("")
    bar.textLeft:SetText("")
    bar.textRight:SetText("")
end

function ns.UpdateAllBars(event, unit)
    if unit and unit ~= PLAYER_UNIT then
        return
    end

    for _, bar in ipairs(barFrames) do
        local def = bar.def
        if def.enabled ~= false then
            if def.type == "resource" then
                UpdateResourceBar(bar, def)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

container:RegisterEvent("PLAYER_ENTERING_WORLD")
container:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
container:RegisterEvent("UNIT_HEALTH")
container:RegisterEvent("UNIT_MAXHEALTH")
container:RegisterEvent("UNIT_POWER_UPDATE")
container:RegisterEvent("UNIT_MAXPOWER")
container:RegisterEvent("UNIT_AURA")
container:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
container:RegisterEvent("SPELL_UPDATE_COOLDOWN")

container:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        ApplyContainerPosition()
        ns.LayoutBars()
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 == "player" then
        if TerninUI_Config and TerninUI_Config.perSpecEnabled then
            ApplyContainerPosition()
            ns.LayoutBars()
            ns.ApplyLockState()
            ns.UpdateAllBars(event, "player")
        end
    end

    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or
       event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or
       event == "UNIT_AURA" or event == "PLAYER_ENTERING_WORLD" or
       event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        ns.UpdateAllBars(event, arg1)
    end
end)
