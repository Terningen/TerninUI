local ADDON_NAME, ns = ...
local PLAYER_UNIT = ns.PLAYER_UNIT
local DEFAULT_CONFIG = ns.DEFAULT_CONFIG

------------------------------------------------------------
-- Power type constants
------------------------------------------------------------

local POWER_RAGE        = (Enum and Enum.PowerType and Enum.PowerType.Rage)       or 1
local POWER_MANA        = (Enum and Enum.PowerType and Enum.PowerType.Mana)       or 0
local POWER_ENERGY      = (Enum and Enum.PowerType and Enum.PowerType.Energy)     or 3
local POWER_FOCUS       = (Enum and Enum.PowerType and Enum.PowerType.Focus)      or 2
local POWER_RUNIC_POWER = (Enum and Enum.PowerType and Enum.PowerType.RunicPower) or 6

local function GetPowerTypeForResource(resource)
    if resource == "rage" then return POWER_RAGE
    elseif resource == "mana" then return POWER_MANA
    elseif resource == "energy" then return POWER_ENERGY
    elseif resource == "focus" then return POWER_FOCUS
    elseif resource == "runic_power" then return POWER_RUNIC_POWER
    end
    return nil
end

------------------------------------------------------------
-- Bar container
------------------------------------------------------------

local container = CreateFrame("Frame", "TerninUI_Container", UIParent)
container:SetSize(150, 10)
ns.container = container

local function ApplyContainerPosition()
    container:ClearAllPoints()
    local pos = TerninUI_Config.position or DEFAULT_CONFIG.position
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
    TerninUI_Config.position = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local barFrames = {}
ns.barFrames = barFrames

function ns.ApplyLockState()
    if TerninUI_Config.locked then
        container:EnableMouse(false)
    else
        container:EnableMouse(true)
    end
end

container:SetMovable(true)
container:RegisterForDrag("LeftButton")
container:SetScript("OnDragStart", function(self)
    if not TerninUI_Config.locked then
        self:StartMoving()
    end
end)
container:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    C_Timer.After(0, SaveContainerPosition)
end)

------------------------------------------------------------
-- Bar layout and creation
------------------------------------------------------------

function ns.LayoutBars()
    local c = TerninUI_Config
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

            local bc = def.color or DEFAULT_CONFIG.bars[i] and DEFAULT_CONFIG.bars[i].color or {1, 1, 1, 1}
            bar:SetStatusBarColor(bc[1] or 1, bc[2] or 1, bc[3] or 1, bc[4] or 1)

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

    for _, def in ipairs(TerninUI_Config.bars) do
        local bar = CreateFrame("StatusBar", "TerninUI_Bar_" .. (def.id or ""), container)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

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

        bar.def = def
        table.insert(barFrames, bar)
    end

    ns.LayoutBars()
end

CreateBars()
ns.ApplyLockState()

------------------------------------------------------------
-- Resource bar updates
------------------------------------------------------------

local function UpdateResourceBar(bar, def)
    local cur, max

    if def.resource == "health" then
        cur = UnitHealth(PLAYER_UNIT)
        max = UnitHealthMax(PLAYER_UNIT)
    elseif def.resource == "mana" then
        cur = UnitPower(PLAYER_UNIT, POWER_MANA)
        max = UnitPowerMax(PLAYER_UNIT, POWER_MANA)
    elseif def.resource == "rage" then
        cur = UnitPower(PLAYER_UNIT, POWER_RAGE)
        max = UnitPowerMax(PLAYER_UNIT, POWER_RAGE)
    elseif def.resource == "energy" then
        cur = UnitPower(PLAYER_UNIT, POWER_ENERGY)
        max = UnitPowerMax(PLAYER_UNIT, POWER_ENERGY)
    elseif def.resource == "focus" then
        cur = UnitPower(PLAYER_UNIT, POWER_FOCUS)
        max = UnitPowerMax(PLAYER_UNIT, POWER_FOCUS)
    elseif def.resource == "runic_power" then
        cur = UnitPower(PLAYER_UNIT, POWER_RUNIC_POWER)
        max = UnitPowerMax(PLAYER_UNIT, POWER_RUNIC_POWER)
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

------------------------------------------------------------
-- Events
------------------------------------------------------------

container:RegisterEvent("PLAYER_ENTERING_WORLD")
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

    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or
       event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or
       event == "UNIT_AURA" or event == "PLAYER_ENTERING_WORLD" or
       event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        ns.UpdateAllBars(event, arg1)
    end
end)
