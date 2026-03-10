local ADDON_NAME, ns = ...
local PLAYER_UNIT = ns.PLAYER_UNIT
local DEFAULT_CONFIG = ns.DEFAULT_CONFIG

------------------------------------------------------------
-- Extra Buttons container
------------------------------------------------------------

local ebContainer = CreateFrame("Frame", "TerninUI_ExtraButtons", UIParent)
ebContainer:SetSize(200, 40)
ebContainer:SetFrameStrata("MEDIUM")
ns.ebContainer = ebContainer

function ns.ApplyEBPosition()
    ebContainer:ClearAllPoints()
    local cfg = TerninUI_Config.extraButtons or DEFAULT_CONFIG.extraButtons
    local pos = cfg.position or DEFAULT_CONFIG.extraButtons.position
    ebContainer:SetPoint(
        pos.point or "CENTER",
        UIParent,
        pos.relativePoint or pos.point or "CENTER",
        pos.x or 0,
        pos.y or -160
    )
end
ns.ApplyEBPosition()

local function SaveEBPosition()
    local point, _, relativePoint, x, y = ebContainer:GetPoint()
    TerninUI_Config.extraButtons.position = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

ebContainer:SetMovable(true)
ebContainer:RegisterForDrag("LeftButton")
ebContainer:SetScript("OnDragStart", function(self)
    if not TerninUI_Config.locked then self:StartMoving() end
end)
ebContainer:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    C_Timer.After(0, SaveEBPosition)
end)

------------------------------------------------------------
-- Aura helper & DurationObject curves
------------------------------------------------------------

local ebIconFrames = {}

local ebDesatCurve, ebGCDFilterCurve
if C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType then
    ebDesatCurve = C_CurveUtil.CreateCurve()
    ebDesatCurve:SetType(Enum.LuaCurveType.Step)
    ebDesatCurve:AddPoint(0, 0)
    ebDesatCurve:AddPoint(0.001, 1)

    ebGCDFilterCurve = C_CurveUtil.CreateCurve()
    ebGCDFilterCurve:SetType(Enum.LuaCurveType.Step)
    ebGCDFilterCurve:AddPoint(0, 0)
    ebGCDFilterCurve:AddPoint(1.6, 1)
end

local CD_TEXT_THRESHOLD = 15

------------------------------------------------------------
-- Icon creation
------------------------------------------------------------

local function FormatCooldownText(seconds)
    if seconds >= 60 then
        return string.format("%dm", math.ceil(seconds / 60))
    elseif seconds >= 10 then
        return string.format("%d", math.floor(seconds))
    elseif seconds > 0 then
        return string.format("%.1f", seconds)
    end
    return ""
end

local function CreateExtraIcon(index, spellID)
    local cfg = TerninUI_Config.extraButtons or DEFAULT_CONFIG.extraButtons
    local size = cfg.iconSize or 32

    local frame = CreateFrame("Frame", "TerninUI_EB_" .. index, ebContainer)
    frame:SetSize(size, size)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.icon = icon

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetReverse(false)
    cooldown:SetHideCountdownNumbers(true)
    cooldown.noCooldownCount = true
    if cooldown.SetSwipeColor then
        cooldown:SetSwipeColor(0, 0, 0, 0.6)
    end
    frame.cooldown = cooldown

    local cdText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cdText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    cdText:SetFont(cdText:GetFont(), 12, "OUTLINE")
    frame.cdText = cdText

    local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    countText:SetFont(countText:GetFont(), 20, "OUTLINE")
    frame.countText = countText

    local belowText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    belowText:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    belowText:SetFont(belowText:GetFont(), 10, "OUTLINE")
    frame.belowText = belowText

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    frame.bg = bg

    frame.spellID = spellID

    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    if info and info.iconID then
        icon:SetTexture(info.iconID)
    elseif GetSpellTexture then
        icon:SetTexture(GetSpellTexture(spellID))
    end

    return frame
end

------------------------------------------------------------
-- Icon update (DurationObject API for combat-safe tracking)
------------------------------------------------------------

local function SafeNumber(val)
    if val == nil then return nil end
    if issecretvalue and issecretvalue(val) then return nil end
    if type(val) ~= "number" then return nil end
    return val
end

local function UpdateExtraIcon(frame)
    if not frame or not frame.spellID then return end
    local spellID = frame.spellID

    frame.cdText:SetText("")
    frame.countText:SetText("")
    frame.belowText:SetText("")

    -- Cooldown swipe: DurationObject is combat-safe, SetCooldown fallback for non-secret spells
    local cdObj = C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(spellID)
    local cdInfo = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)

    frame.cooldown:SetReverse(false)
    if cdObj then
        frame.cooldown:SetCooldownFromDurationObject(cdObj)
        frame.cooldown:SetDrawSwipe(true)
    elseif cdInfo and cdInfo.startTime and cdInfo.duration then
        local s = SafeNumber(cdInfo.startTime)
        local d = SafeNumber(cdInfo.duration)
        if s and d and d > 0 then
            frame.cooldown:SetCooldown(s, d)
            frame.cooldown:SetDrawSwipe(true)
        else
            frame.cooldown:Clear()
        end
    else
        frame.cooldown:Clear()
    end

    -- Desaturation
    if cdObj and ebDesatCurve and cdObj.EvaluateRemainingDuration then
        frame.icon:SetDesaturation(cdObj:EvaluateRemainingDuration(ebDesatCurve, 0) or 0)
    elseif cdInfo then
        local s = SafeNumber(cdInfo.startTime)
        local d = SafeNumber(cdInfo.duration)
        if s and d and d > 1.5 then
            frame.icon:SetDesaturation(((s + d) - GetTime()) > 0 and 1 or 0)
        else
            frame.icon:SetDesaturation(0)
        end
    else
        frame.icon:SetDesaturation(0)
    end

    -- Charge display: cache values so they survive secret-value lockout
    local chargeInfo = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellID)
    local cur = chargeInfo and SafeNumber(chargeInfo.currentCharges)
    local max = chargeInfo and SafeNumber(chargeInfo.maxCharges)
    if max then frame._maxCharges = max end
    if cur then frame._lastCharges = cur end
    max = max or frame._maxCharges
    cur = cur or frame._lastCharges

    -- Detect charge spend: if cooldown is active but cache says full, decrement
    if max and max > 1 and cur then
        local onCD = cdObj and ebDesatCurve and cdObj.EvaluateRemainingDuration
            and (cdObj:EvaluateRemainingDuration(ebDesatCurve, 0) or 0) > 0
        if onCD and cur == max then
            cur = max - 1
            frame._lastCharges = cur
        end
        -- If cooldown is NOT active, charges must be full
        if not onCD then
            cur = max
            frame._lastCharges = cur
        end
    end

    if max and max > 1 and cur then
        frame.countText:SetText(tostring(cur))
        -- Cooldown timer below icon for charge spells
        local cdInfo = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)
        if cdInfo then
            local s = SafeNumber(cdInfo.startTime)
            local d = SafeNumber(cdInfo.duration)
            if s and d and d > 1.5 then
                local remaining = (s + d) - GetTime()
                if remaining > 0 then
                    frame.belowText:SetTextColor(1, 1, 1)
                    frame.belowText:SetText(FormatCooldownText(remaining))
                end
            end
        end
    else
        -- Normal spell: cooldown text centered, <=15s only
        local cdInfo = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)
        if cdInfo then
            local s = SafeNumber(cdInfo.startTime)
            local d = SafeNumber(cdInfo.duration)
            if s and d and d > 1.5 then
                local remaining = (s + d) - GetTime()
                if remaining > 0 and remaining <= CD_TEXT_THRESHOLD then
                    frame.cdText:SetTextColor(1, 1, 1)
                    frame.cdText:SetText(FormatCooldownText(remaining))
                end
            end
        end
    end
end

------------------------------------------------------------
-- Layout
------------------------------------------------------------

function ns.LayoutExtraButtons()
    local cfg = TerninUI_Config.extraButtons or DEFAULT_CONFIG.extraButtons
    if not cfg.enabled then
        ebContainer:Hide()
        return
    end

    local spellIDs = cfg.spellIDs or {}
    if #spellIDs == 0 then
        ebContainer:Hide()
        return
    end

    ebContainer:Show()
    local size = cfg.iconSize or 32
    local spacing = cfg.spacing or 2

    for i = #spellIDs + 1, #ebIconFrames do
        ebIconFrames[i]:Hide()
    end

    for i, sid in ipairs(spellIDs) do
        local frame = ebIconFrames[i]
        if not frame then
            frame = CreateExtraIcon(i, sid)
            ebIconFrames[i] = frame
        end

        frame.spellID = sid
        frame:SetSize(size, size)

        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(sid)
        if info and info.iconID then
            frame.icon:SetTexture(info.iconID)
        elseif GetSpellTexture then
            frame.icon:SetTexture(GetSpellTexture(sid))
        end

        frame:ClearAllPoints()
        if i == 1 then
            frame:SetPoint("LEFT", ebContainer, "LEFT", 0, 0)
        else
            frame:SetPoint("LEFT", ebIconFrames[i - 1], "RIGHT", spacing, 0)
        end
        frame:Show()
    end

    local totalW = (#spellIDs * size) + ((#spellIDs - 1) * spacing)
    ebContainer:SetSize(totalW, size)

    if TerninUI_Config.locked then
        ebContainer:EnableMouse(false)
    else
        ebContainer:EnableMouse(true)
    end
end

------------------------------------------------------------
-- OnUpdate ticker
------------------------------------------------------------

local function UpdateExtraButtons()
    for _, frame in ipairs(ebIconFrames) do
        if frame:IsShown() then
            UpdateExtraIcon(frame)
        end
    end
end

local ebUpdateElapsed = 0
ebContainer:SetScript("OnUpdate", function(self, elapsed)
    if not self:IsShown() then return end
    ebUpdateElapsed = ebUpdateElapsed + elapsed
    if ebUpdateElapsed < 0.1 then return end
    ebUpdateElapsed = 0
    UpdateExtraButtons()
end)
