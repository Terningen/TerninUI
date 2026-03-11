--[[
    TerninUI - Options
    Settings UI, panel builders, and options refresh.
]]

local ADDON_NAME, ns = ...
local DEFAULT_CONFIG = ns.DEFAULT_CONFIG
local LayoutBars = ns.LayoutBars
local UpdateAllBars = ns.UpdateAllBars
local ApplyLockState = ns.ApplyLockState
local barFrames = ns.barFrames

local PAD = 24
local OPTIONS_CONTENT_H = 600

-- ---------------------------------------------------------------------------
-- UI helpers
-- ---------------------------------------------------------------------------

local function CreateSubcategoryWrapper(name, contentH)
    contentH = contentH or 600
    local wrapper = CreateFrame("Frame", "TerninUI_" .. name:gsub("%s+", ""), UIParent)
    local scroll = CreateFrame("ScrollFrame", wrapper:GetName() .. "Scroll", wrapper, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(400, contentH)
    scroll:SetScrollChild(content)
    wrapper.content = content
    return wrapper
end

local function CleanSliderStyle(slider)
    if slider.SetBackdrop then
        slider:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = nil,
            tile = true,
            tileSize = 8,
            edgeSize = 0,
            insets = { left = 2, right = 2, top = 4, bottom = 4 }
        })
        slider:SetBackdropColor(0.25, 0.25, 0.25, 0.95)
    end
end

local function AddSectionLine(panel, anchor)
    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.4, 0.4, 0.4, 0.5)
    line:SetHeight(1)
    line:SetPoint("TOP", anchor, "BOTTOM", 0, -12)
    line:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    line:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    return line
end

local function AddOptionRow(panel, anchor, gap)
    gap = gap or 18
    local row = CreateFrame("Frame", nil, panel)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
    row:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    row:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    row:SetHeight(1)
    return row
end

local function CreateColorOption(panel, anchor, text, getColor, setColor)
    local row = AddOptionRow(panel, anchor, 14)
    row:SetHeight(24)

    local button = CreateFrame("Button", nil, row)
    button:SetSize(20, 20)
    button:SetPoint("LEFT", row, "LEFT", 0, 0)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", button, "RIGHT", 8, 0)
    label:SetText(text)
    label:SetTextColor(1, 0.82, 0)

    button.tex = button:CreateTexture(nil, "BACKGROUND")
    button.tex:SetAllPoints(true)
    if button.SetBackdrop then
        button:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        button:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    end

    local function updateSwatch()
        local c = getColor()
        button.tex:SetColorTexture(c[1] or 1, c[2] or 1, c[3] or 1, 1)
    end

    button.update = updateSwatch
    row.update = updateSwatch
    updateSwatch()

    button:SetScript("OnClick", function()
        if not ColorPickerFrame then return end
        local c = getColor()
        local r, g, b, a = c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1

        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame.previousValues = { r = r, g = g, b = b, a = a or 1 }
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b, opacity = a or 1, hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or 1
                    setColor(nr, ng, nb, na)
                    updateSwatch()
                    LayoutBars()
                end,
                cancelFunc = function()
                    local prev = ColorPickerFrame.previousValues
                    if prev then
                        setColor(prev.r or prev[1], prev.g or prev[2], prev.b or prev[3], prev.a or prev[4] or 1)
                        updateSwatch()
                        LayoutBars()
                    end
                end
            })
        else
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame.hasOpacity = true
            ColorPickerFrame.opacity = 1 - a
            ColorPickerFrame.previousValues = { r, g, b, a }
            local function pickerCallback()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = 1 - (ColorPickerFrame.opacity or 0)
                setColor(nr, ng, nb, na)
                updateSwatch()
                LayoutBars()
            end
            ColorPickerFrame.func = pickerCallback
            ColorPickerFrame.opacityFunc = pickerCallback
            ColorPickerFrame.cancelFunc = function(prev)
                if not prev then return end
                setColor(prev[1], prev[2], prev[3], prev[4])
                updateSwatch()
                LayoutBars()
            end
            ColorPickerFrame:Hide()
            ColorPickerFrame:Show()
        end
    end)

    return row
end

local optionsRefs = {}

-- Creates a 0-100% backdrop transparency slider for a bar.
local function CreateBgAlphaSlider(panel, barIndex, anchor)
    local slider = CreateFrame("Slider", "TerninUI_BgAlpha" .. barIndex, panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -28)
    slider:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    slider:SetMinMaxValues(0, 100)
    slider:SetValueStep(5)
    _G[slider:GetName() .. "Low"]:SetText("0%")
    _G[slider:GetName() .. "High"]:SetText("100%")
    _G[slider:GetName() .. "Text"]:SetText("Backdrop transparency")
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        TerninUI_Config.bars[barIndex].bgAlpha = value
        _G[self:GetName() .. "Text"]:SetText("Backdrop transparency: " .. value .. "%")
        LayoutBars()
    end)
    local def = DEFAULT_CONFIG.bars[barIndex]
    local v = TerninUI_Config.bars[barIndex].bgAlpha
    if v == nil then v = def and def.bgAlpha or 0 end
    slider:SetValue(v)
    _G[slider:GetName() .. "Text"]:SetText("Backdrop transparency: " .. v .. "%")
    CleanSliderStyle(slider)
    return slider
end

local function CreateWidthSlider(panel, index, anchor, labelText)
    local slider = CreateFrame("Slider", "$parent_" .. labelText:gsub("%s+", "") .. "Width", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -28)
    slider:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    slider:SetMinMaxValues(100, 500)
    slider:SetValueStep(10)
    _G[slider:GetName() .. "Low"]:SetText("100")
    _G[slider:GetName() .. "High"]:SetText("500")
    _G[slider:GetName() .. "Text"]:SetText(labelText .. " width")
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor((value or self:GetValue()) + 0.5)
        TerninUI_Config.bars[index].width = value
        _G[self:GetName() .. "Text"]:SetText(labelText .. " width: " .. value)
        LayoutBars()
    end)
    local initVal = (TerninUI_Config.bars[index] and TerninUI_Config.bars[index].width) or DEFAULT_CONFIG.bars[index].width or 150
    slider:SetValue(initVal)
    _G[slider:GetName() .. "Text"]:SetText(labelText .. " width: " .. initVal)
    CleanSliderStyle(slider)
    return slider
end

local function CreateHeightSlider(panel, index, anchor, labelText)
    local slider = CreateFrame("Slider", "$parent_" .. labelText:gsub("%s+", "") .. "Height", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -28)
    slider:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    slider:SetMinMaxValues(10, 40)
    slider:SetValueStep(1)
    _G[slider:GetName() .. "Low"]:SetText("10")
    _G[slider:GetName() .. "High"]:SetText("40")
    _G[slider:GetName() .. "Text"]:SetText(labelText .. " height")
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor((value or self:GetValue()) + 0.5)
        TerninUI_Config.bars[index].height = value
        _G[self:GetName() .. "Text"]:SetText(labelText .. " height: " .. value)
        LayoutBars()
    end)
    local initVal = (TerninUI_Config.bars[index] and TerninUI_Config.bars[index].height) or DEFAULT_CONFIG.bars[index].height or 10
    slider:SetValue(initVal)
    _G[slider:GetName() .. "Text"]:SetText(labelText .. " height: " .. initVal)
    CleanSliderStyle(slider)
    return slider
end

local function CreateEnableCheckbox(panel, anchor, label, getEnabled, setEnabled, onChanged)
    local row = CreateFrame("Frame", nil, panel)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
    row:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    row:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    row:SetHeight(24)
    row:EnableMouse(true)

    local check = CreateFrame("CheckButton", nil, row)
    check:SetSize(24, 24)
    check:SetPoint("LEFT", row, "LEFT", 0, 0)
    check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetScript("OnClick", function(self)
        local enabled = self:GetChecked() and true or false
        setEnabled(enabled)
        if onChanged then onChanged() end
    end)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 8, 0)
    text:SetText(label)
    text:SetTextColor(1, 0.82, 0)

    row.check = check
    row.SetChecked = function(self, enabled) self.check:SetChecked(enabled and true or false) end
    row.GetChecked = function(self) return self.check:GetChecked() end
    row.Refresh = function(self) self:SetChecked(getEnabled()) end
    row.check:SetChecked(getEnabled() and true or false)
    return row
end

------------------------------------------------------------
-- Panel builders
------------------------------------------------------------

local function BuildDefaultBarsPanel(panel)
    local defaultHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    defaultHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -16)
    defaultHeader:SetText("Default")
    defaultHeader:SetTextColor(1, 0.82, 0)

    local lockCheck = CreateEnableCheckbox(panel, defaultHeader, "Lock elements",
        function() return TerninUI_Config.locked end,
        function(locked)
            TerninUI_Config.locked = locked
            ApplyLockState()
        end)
    optionsRefs.lockCheck = lockCheck

    local spacingSlider = CreateFrame("Slider", "$parent_BarSpacing", panel, "OptionsSliderTemplate")
    spacingSlider:SetPoint("TOPLEFT", lockCheck, "BOTTOMLEFT", 0, -22)
    spacingSlider:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    spacingSlider:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    spacingSlider:SetMinMaxValues(0, 30)
    spacingSlider:SetValueStep(1)
    _G[spacingSlider:GetName() .. "Low"]:SetText("0")
    _G[spacingSlider:GetName() .. "High"]:SetText("30")
    _G[spacingSlider:GetName() .. "Text"]:SetText("Bar spacing")
    spacingSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        TerninUI_Config.barSpacing = value
        _G[self:GetName() .. "Text"]:SetText("Bar spacing: " .. value)
        LayoutBars()
    end)
    spacingSlider:SetValue(TerninUI_Config.barSpacing or DEFAULT_CONFIG.barSpacing)
    _G[spacingSlider:GetName() .. "Text"]:SetText("Bar spacing: " .. (TerninUI_Config.barSpacing or DEFAULT_CONFIG.barSpacing))
    CleanSliderStyle(spacingSlider)
    optionsRefs.spacingSlider = spacingSlider
end

local function BuildHealthPanel(panel)
    local healthHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    healthHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -16)
    healthHeader:SetText("Health Bar")
    healthHeader:SetTextColor(1, 0.82, 0)

    local healthCheck = CreateEnableCheckbox(panel, healthHeader, "Enable Health Bar",
        function() return TerninUI_Config.bars[1].enabled ~= false end,
        function(enabled)
            TerninUI_Config.bars[1].enabled = enabled
            LayoutBars()
            UpdateAllBars("UNIT_HEALTH", "player")
        end)
    optionsRefs.healthCheck = healthCheck

    local healthWidthSlider = CreateWidthSlider(panel, 1, healthCheck, "Health bar")
    optionsRefs.healthWidthSlider = healthWidthSlider

    local healthHeightSlider = CreateHeightSlider(panel, 1, healthWidthSlider, "Health bar")
    optionsRefs.healthHeightSlider = healthHeightSlider

    local healthBarColorBtn = CreateColorOption(panel, healthHeightSlider, "Health bar color", function()
        return TerninUI_Config.bars[1].color or DEFAULT_CONFIG.bars[1].color
    end, function(r, g, b, a)
        TerninUI_Config.bars[1].color = { r, g, b, a }
        if barFrames[1] then barFrames[1]:SetStatusBarColor(r, g, b, a) end
    end)
    optionsRefs.healthBarColorBtn = healthBarColorBtn

    local healthBgColorBtn = CreateColorOption(panel, healthBarColorBtn, "Backdrop color", function()
        return TerninUI_Config.bars[1].bgColor or DEFAULT_CONFIG.bars[1].bgColor or {0, 0, 0, 1}
    end, function(r, g, b, a)
        TerninUI_Config.bars[1].bgColor = { r, g, b, a }
        LayoutBars()
    end)
    optionsRefs.healthBgColorBtn = healthBgColorBtn

    optionsRefs.healthBgAlphaSlider = CreateBgAlphaSlider(panel, 1, healthBgColorBtn)
end

local function BuildPowerPanel(panel)
    local powerHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    powerHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -16)
    powerHeader:SetText("Power Bar")
    powerHeader:SetTextColor(1, 0.82, 0)

    local rageCheck = CreateEnableCheckbox(panel, powerHeader, "Enable Power Bar",
        function() return TerninUI_Config.bars[2].enabled ~= false end,
        function(enabled)
            TerninUI_Config.bars[2].enabled = enabled
            LayoutBars()
            UpdateAllBars("UNIT_POWER_UPDATE", "player")
        end)
    optionsRefs.rageCheck = rageCheck

    local rageWidthSlider = CreateWidthSlider(panel, 2, rageCheck, "Power bar")
    optionsRefs.rageWidthSlider = rageWidthSlider

    local rageHeightSlider = CreateHeightSlider(panel, 2, rageWidthSlider, "Power bar")
    optionsRefs.rageHeightSlider = rageHeightSlider

    local markerEnabledCheck = CreateEnableCheckbox(panel, rageHeightSlider, "Enable marker",
        function() return TerninUI_Config.bars[2].markerEnabled == true end,
        function(enabled)
            TerninUI_Config.bars[2].markerEnabled = enabled
            LayoutBars()
            UpdateAllBars("UNIT_POWER_UPDATE", "player")
        end)
    optionsRefs.markerEnabledCheck = markerEnabledCheck

    local markerValueSlider = CreateFrame("Slider", "$parent_PowerMarkerValue", panel, "OptionsSliderTemplate")
    markerValueSlider:SetPoint("TOPLEFT", markerEnabledCheck, "BOTTOMLEFT", 0, -28)
    markerValueSlider:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    markerValueSlider:SetMinMaxValues(0, 200)
    markerValueSlider:SetValueStep(1)
    _G[markerValueSlider:GetName() .. "Low"]:SetText("0")
    _G[markerValueSlider:GetName() .. "High"]:SetText("200")
    _G[markerValueSlider:GetName() .. "Text"]:SetText("Resource value (e.g. 30 rage)")
    markerValueSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        TerninUI_Config.bars[2].markerValue = value
        _G[self:GetName() .. "Text"]:SetText("Resource value: " .. value .. " (e.g. 30 rage)")
        LayoutBars()
        UpdateAllBars("UNIT_POWER_UPDATE", "player")
    end)
    do
        local v = TerninUI_Config.bars[2].markerValue or TerninUI_Config.bars[2].markerPercent or 30
        markerValueSlider:SetValue(v)
        _G[markerValueSlider:GetName() .. "Text"]:SetText("Resource value: " .. v .. " (e.g. 30 rage)")
    end
    CleanSliderStyle(markerValueSlider)
    optionsRefs.markerValueSlider = markerValueSlider

    local markerColorRow = CreateFrame("Frame", nil, panel)
    markerColorRow:SetPoint("TOPLEFT", markerValueSlider, "BOTTOMLEFT", 0, -14)
    markerColorRow:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    markerColorRow:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    markerColorRow:SetHeight(24)
    local markerColorBtn = CreateFrame("Button", nil, markerColorRow)
    markerColorBtn:SetSize(20, 20)
    markerColorBtn:SetPoint("LEFT", markerColorRow, "LEFT", 0, 0)
    local markerColorLabel = markerColorRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    markerColorLabel:SetPoint("LEFT", markerColorBtn, "RIGHT", 8, 0)
    markerColorLabel:SetText("Marker color")
    markerColorLabel:SetTextColor(1, 0.82, 0)
    markerColorBtn.tex = markerColorBtn:CreateTexture(nil, "BACKGROUND")
    markerColorBtn.tex:SetAllPoints(true)
    if markerColorBtn.SetBackdrop then
        markerColorBtn:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        markerColorBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    end
    local function updateMarkerColorSwatch()
        local c = TerninUI_Config.bars[2].markerColor or DEFAULT_CONFIG.bars[2].markerColor or {1, 1, 1, 0.9}
        markerColorBtn.tex:SetColorTexture(c[1] or 1, c[2] or 1, c[3] or 1, 1)
    end
    markerColorBtn.update = updateMarkerColorSwatch
    markerColorBtn:SetScript("OnClick", function()
        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            local c = TerninUI_Config.bars[2].markerColor or DEFAULT_CONFIG.bars[2].markerColor or {1, 1, 1, 0.9}
            local r, g, b, a = c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
            ColorPickerFrame.previousValues = { r = r, g = g, b = b, a = a }
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b, opacity = a or 1, hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or 1
                    TerninUI_Config.bars[2].markerColor = { nr, ng, nb, na }
                    updateMarkerColorSwatch()
                    LayoutBars()
                end,
                cancelFunc = function()
                    local prev = ColorPickerFrame.previousValues
                    if prev then
                        TerninUI_Config.bars[2].markerColor = { prev.r or 1, prev.g or 1, prev.b or 1, prev.a or 1 }
                        updateMarkerColorSwatch()
                        LayoutBars()
                    end
                end
            })
        end
    end)
    updateMarkerColorSwatch()
    optionsRefs.markerColorBtn = markerColorBtn

    local POWER_OPTIONS = {
        { value = "rage", text = "Rage" },
        { value = "mana", text = "Mana" },
        { value = "energy", text = "Energy" },
        { value = "focus", text = "Focus" },
        { value = "runic_power", text = "Runic Power" },
    }
    local powerTypeRow = CreateFrame("Frame", nil, panel)
    powerTypeRow:SetPoint("TOPLEFT", markerColorRow, "BOTTOMLEFT", 0, -14)
    powerTypeRow:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    powerTypeRow:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    powerTypeRow:SetHeight(28)
    local powerTypeDropdown = CreateFrame("Frame", "$parent_PowerType", powerTypeRow, "UIDropDownMenuTemplate")
    powerTypeDropdown:SetPoint("LEFT", powerTypeRow, "LEFT", 0, 0)
    local powerTypeLabel = powerTypeRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    powerTypeLabel:SetPoint("LEFT", powerTypeDropdown, "RIGHT", 8, 0)
    powerTypeLabel:SetText("Power type")
    powerTypeLabel:SetTextColor(1, 0.82, 0)
    UIDropDownMenu_SetWidth(powerTypeDropdown, 120)
    local function PowerTypeDropdown_Initialize(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, opt in ipairs(POWER_OPTIONS) do
            info.text = opt.text
            info.value = opt.value
            info.func = function(button)
                TerninUI_Config.bars[2].resource = opt.value
                TerninUI_Config.bars[2].label = opt.text
                UIDropDownMenu_SetSelectedValue(powerTypeDropdown, opt.value)
                if UIDropDownMenu_SetText then UIDropDownMenu_SetText(powerTypeDropdown, opt.text) end
            end
            info.checked = (TerninUI_Config.bars[2].resource == opt.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(powerTypeDropdown, PowerTypeDropdown_Initialize)
    optionsRefs.powerTypeDropdown = powerTypeDropdown
    optionsRefs.POWER_OPTIONS = POWER_OPTIONS

    local powerBarColorRow = CreateFrame("Frame", nil, panel)
    powerBarColorRow:SetPoint("TOPLEFT", powerTypeRow, "BOTTOMLEFT", 0, -14)
    powerBarColorRow:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    powerBarColorRow:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    powerBarColorRow:SetHeight(24)
    local rageBarColorBtn = CreateFrame("Button", nil, powerBarColorRow)
    rageBarColorBtn:SetSize(20, 20)
    rageBarColorBtn:SetPoint("LEFT", powerBarColorRow, "LEFT", 0, 0)
    local powerBarColorLabel = powerBarColorRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    powerBarColorLabel:SetPoint("LEFT", rageBarColorBtn, "RIGHT", 8, 0)
    powerBarColorLabel:SetText("Power bar color")
    powerBarColorLabel:SetTextColor(1, 0.82, 0)
    rageBarColorBtn.tex = rageBarColorBtn:CreateTexture(nil, "BACKGROUND")
    rageBarColorBtn.tex:SetAllPoints(true)
    if rageBarColorBtn.SetBackdrop then
        rageBarColorBtn:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        rageBarColorBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    end
    local function updatePowerBarColorSwatch()
        local c = TerninUI_Config.bars[2].color or DEFAULT_CONFIG.bars[2].color
        rageBarColorBtn.tex:SetColorTexture(c[1] or 1, c[2] or 1, c[3] or 1, 1)
    end
    rageBarColorBtn.update = updatePowerBarColorSwatch
    rageBarColorBtn:SetScript("OnClick", function()
        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            local c = TerninUI_Config.bars[2].color or DEFAULT_CONFIG.bars[2].color
            local r, g, b, a = c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
            ColorPickerFrame.previousValues = { r = r, g = g, b = b, a = a }
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b, opacity = a or 1, hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or 1
                    TerninUI_Config.bars[2].color = { nr, ng, nb, na }
                    if barFrames[2] then barFrames[2]:SetStatusBarColor(nr, ng, nb, na) end
                    updatePowerBarColorSwatch()
                end,
                cancelFunc = function()
                    local prev = ColorPickerFrame.previousValues
                    if prev then
                        TerninUI_Config.bars[2].color = { prev.r or 1, prev.g or 1, prev.b or 1, prev.a or 1 }
                        if barFrames[2] then barFrames[2]:SetStatusBarColor(prev.r or 1, prev.g or 1, prev.b or 1, prev.a or 1) end
                        updatePowerBarColorSwatch()
                    end
                end
            })
        end
    end)
    updatePowerBarColorSwatch()
    optionsRefs.rageBarColorBtn = rageBarColorBtn

    local powerBgColorBtn = CreateColorOption(panel, powerBarColorRow, "Backdrop color", function()
        return TerninUI_Config.bars[2].bgColor or DEFAULT_CONFIG.bars[2].bgColor or {0, 0, 0, 1}
    end, function(r, g, b, a)
        TerninUI_Config.bars[2].bgColor = { r, g, b, a }
        LayoutBars()
    end)
    optionsRefs.powerBgColorBtn = powerBgColorBtn

    optionsRefs.powerBgAlphaSlider = CreateBgAlphaSlider(panel, 2, powerBgColorBtn)
end

local function BuildAbsorbPanel(panel)
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -16)
    header:SetText("Shield Pool")
    header:SetTextColor(1, 0.82, 0)

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    hint:SetText("Shows your total absorb shield (Ignore Pain, Power Word: Shield, etc.).")
    hint:SetTextColor(0.7, 0.7, 0.7)

    local absorbCheck = CreateEnableCheckbox(panel, hint, "Enable Shield Pool",
        function() return TerninUI_Config.bars[3].enabled ~= false end,
        function(enabled)
            TerninUI_Config.bars[3].enabled = enabled
            LayoutBars()
            UpdateAllBars("UNIT_ABSORB_AMOUNT_CHANGED", "player")
        end)
    optionsRefs.absorbCheck = absorbCheck

    local absorbWidthSlider = CreateWidthSlider(panel, 3, absorbCheck, "Shield pool bar")
    optionsRefs.absorbWidthSlider = absorbWidthSlider

    local absorbHeightSlider = CreateHeightSlider(panel, 3, absorbWidthSlider, "Shield pool bar")
    optionsRefs.absorbHeightSlider = absorbHeightSlider

    local absorbMaxPercentSlider = CreateFrame("Slider", "$parent_AbsorbMaxPercent", panel, "OptionsSliderTemplate")
    absorbMaxPercentSlider:SetPoint("TOPLEFT", absorbHeightSlider, "BOTTOMLEFT", 0, -28)
    absorbMaxPercentSlider:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    absorbMaxPercentSlider:SetMinMaxValues(1, 100)
    absorbMaxPercentSlider:SetValueStep(1)
    _G[absorbMaxPercentSlider:GetName() .. "Low"]:SetText("1%")
    _G[absorbMaxPercentSlider:GetName() .. "High"]:SetText("100%")
    _G[absorbMaxPercentSlider:GetName() .. "Text"]:SetText("% of max health (30% for Warrior Ignore Pain)")
    absorbMaxPercentSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        TerninUI_Config.bars[3].absorbMaxPercent = value
        _G[self:GetName() .. "Text"]:SetText(value .. "% of max health (30% for Warrior Ignore Pain)")
        LayoutBars()
        UpdateAllBars("UNIT_ABSORB_AMOUNT_CHANGED", "player")
    end)
    do
        local v = TerninUI_Config.bars[3].absorbMaxPercent or DEFAULT_CONFIG.bars[3].absorbMaxPercent or 30
        absorbMaxPercentSlider:SetValue(v)
        _G[absorbMaxPercentSlider:GetName() .. "Text"]:SetText(v .. "% of max health (30% for Warrior Ignore Pain)")
    end
    CleanSliderStyle(absorbMaxPercentSlider)
    optionsRefs.absorbMaxPercentSlider = absorbMaxPercentSlider

    local absorbColorBtn = CreateColorOption(panel, absorbMaxPercentSlider, "Shield pool bar color", function()
        return TerninUI_Config.bars[3].color or DEFAULT_CONFIG.bars[3].color
    end, function(r, g, b, a)
        TerninUI_Config.bars[3].color = { r, g, b, a }
        if barFrames[3] then barFrames[3]:SetStatusBarColor(r, g, b, a) end
    end)
    optionsRefs.absorbColorBtn = absorbColorBtn

    local absorbBgColorBtn = CreateColorOption(panel, absorbColorBtn, "Backdrop color", function()
        return TerninUI_Config.bars[3].bgColor or DEFAULT_CONFIG.bars[3].bgColor or {0, 0, 0, 1}
    end, function(r, g, b, a)
        TerninUI_Config.bars[3].bgColor = { r, g, b, a }
        LayoutBars()
    end)
    optionsRefs.absorbBgColorBtn = absorbBgColorBtn

    optionsRefs.absorbBgAlphaSlider = CreateBgAlphaSlider(panel, 3, absorbBgColorBtn)
end

-- ---------------------------------------------------------------------------
-- Settings registration (WoW Settings UI or legacy Interface Options)
-- ---------------------------------------------------------------------------

local healthWrapper, powerWrapper, buffBarsWrapper
local optionsWrapper, optionsContent

local terninUICategory
if Settings and Settings.RegisterCanvasLayoutSubcategory then
    local parentFrame = CreateFrame("Frame", "TerninUI_Parent", UIParent)
    parentFrame.name = "TerninUI"

    local parentScroll = CreateFrame("ScrollFrame", "TerninUI_ParentScroll", parentFrame, "UIPanelScrollFrameTemplate")
    parentScroll:SetPoint("TOPLEFT", 0, 0)
    parentScroll:SetPoint("BOTTOMRIGHT", 0, 0)
    local parentContent = CreateFrame("Frame", nil, parentScroll)
    parentContent:SetSize(400, 150)
    parentScroll:SetScrollChild(parentContent)
    parentFrame.content = parentContent

    healthWrapper = CreateSubcategoryWrapper("HealthBar", 220)
    powerWrapper = CreateSubcategoryWrapper("PowerBar", 320)
    buffBarsWrapper = CreateSubcategoryWrapper("BuffBars", 320)
    local function RefreshOnShow()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, OptionsRefresh)
        else
            OptionsRefresh()
        end
    end
    for _, w in ipairs({ parentFrame, healthWrapper, powerWrapper, buffBarsWrapper }) do
        w:SetScript("OnShow", RefreshOnShow)
    end

    BuildDefaultBarsPanel(parentContent)
    BuildHealthPanel(healthWrapper.content)
    BuildPowerPanel(powerWrapper.content)
    BuildAbsorbPanel(buffBarsWrapper.content)

    terninUICategory = Settings.RegisterCanvasLayoutCategory(parentFrame, "TerninUI")
    Settings.RegisterCanvasLayoutSubcategory(terninUICategory, healthWrapper, "Health Bar")
    Settings.RegisterCanvasLayoutSubcategory(terninUICategory, powerWrapper, "Power Bar")
    Settings.RegisterCanvasLayoutSubcategory(terninUICategory, buffBarsWrapper, "Shield Pool")
    Settings.RegisterAddOnCategory(terninUICategory)
    optionsWrapper = parentFrame
else
    optionsWrapper = CreateFrame("Frame", "TerninUI_OptionsWrapper", UIParent)
    optionsWrapper.name = "TerninUI"
    local optionsScroll = CreateFrame("ScrollFrame", "TerninUI_OptionsScroll", optionsWrapper, "UIPanelScrollFrameTemplate")
    optionsWrapper.scroll = optionsScroll
    optionsScroll:SetPoint("TOPLEFT", 0, 0)
    optionsScroll:SetPoint("BOTTOMRIGHT", 0, 0)
    optionsContent = CreateFrame("Frame", nil, optionsScroll)
    optionsContent:SetSize(400, OPTIONS_CONTENT_H)
    optionsScroll:SetScrollChild(optionsContent)

    local defaultBarsContent = CreateFrame("Frame", nil, optionsContent)
    defaultBarsContent:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 0, 0)
    defaultBarsContent:SetPoint("RIGHT", optionsContent, "RIGHT", 0, 0)
    defaultBarsContent:SetHeight(150)
    BuildDefaultBarsPanel(defaultBarsContent)

    local healthContent = CreateFrame("Frame", nil, optionsContent)
    healthContent:SetPoint("TOPLEFT", defaultBarsContent, "BOTTOMLEFT", 0, -20)
    healthContent:SetPoint("RIGHT", optionsContent, "RIGHT", 0, 0)
    healthContent:SetHeight(220)
    BuildHealthPanel(healthContent)

    local powerContent = CreateFrame("Frame", nil, optionsContent)
    powerContent:SetPoint("TOPLEFT", healthContent, "BOTTOMLEFT", 0, -20)
    powerContent:SetPoint("RIGHT", optionsContent, "RIGHT", 0, 0)
    powerContent:SetHeight(320)
    BuildPowerPanel(powerContent)

    local buffBarsContent = CreateFrame("Frame", nil, optionsContent)
    buffBarsContent:SetPoint("TOPLEFT", powerContent, "BOTTOMLEFT", 0, -20)
    buffBarsContent:SetPoint("RIGHT", optionsContent, "RIGHT", 0, 0)
    buffBarsContent:SetHeight(280)
    BuildAbsorbPanel(buffBarsContent)

    optionsWrapper:SetScript("OnShow", function()
        local w = optionsWrapper:GetWidth()
        if w and w > 0 then optionsContent:SetWidth(w - 30) end
        OptionsRefresh()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, OptionsRefresh)
        end
    end)
    optionsWrapper:SetScript("OnSizeChanged", function()
        local w = optionsWrapper:GetWidth()
        if w and w > 0 then optionsContent:SetWidth(w - 30) end
    end)
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsWrapper)
    end
end

-- ---------------------------------------------------------------------------
-- Options refresh (syncs UI controls with saved config)
-- ---------------------------------------------------------------------------

function OptionsRefresh()
    local c = TerninUI_Config
    local r = optionsRefs
    if r.lockCheck and r.lockCheck.SetChecked then r.lockCheck:SetChecked(c.locked) end
    if r.spacingSlider then
        r.spacingSlider:SetValue(c.barSpacing or DEFAULT_CONFIG.barSpacing)
        _G[r.spacingSlider:GetName() .. "Text"]:SetText("Bar spacing: " .. (c.barSpacing or DEFAULT_CONFIG.barSpacing))
    end

    if r.healthCheck and r.healthCheck.SetChecked then r.healthCheck:SetChecked(c.bars[1].enabled ~= false) end
    if r.rageCheck and r.rageCheck.SetChecked then r.rageCheck:SetChecked(c.bars[2].enabled ~= false) end
    if r.markerEnabledCheck and r.markerEnabledCheck.SetChecked then r.markerEnabledCheck:SetChecked(c.bars[2].markerEnabled == true) end
    if r.absorbCheck and r.absorbCheck.SetChecked then r.absorbCheck:SetChecked(c.bars[3] and c.bars[3].enabled ~= false) end

    if r.healthWidthSlider then
        r.healthWidthSlider:SetValue(c.bars[1].width or DEFAULT_CONFIG.bars[1].width or 150)
        _G[r.healthWidthSlider:GetName() .. "Text"]:SetText("Health bar width: " .. (c.bars[1].width or 150))
    end
    if r.healthHeightSlider then r.healthHeightSlider:SetValue(c.bars[1].height or DEFAULT_CONFIG.bars[1].height) end
    if r.healthBgColorBtn and r.healthBgColorBtn.update then r.healthBgColorBtn.update() end
    if r.healthBgAlphaSlider then
        local v = c.bars[1].bgAlpha
        if v == nil then v = DEFAULT_CONFIG.bars[1].bgAlpha or 0 end
        r.healthBgAlphaSlider:SetValue(v)
        _G[r.healthBgAlphaSlider:GetName() .. "Text"]:SetText("Backdrop transparency: " .. v .. "%")
    end
    if r.rageWidthSlider then
        r.rageWidthSlider:SetValue(c.bars[2].width or DEFAULT_CONFIG.bars[2].width or 150)
        _G[r.rageWidthSlider:GetName() .. "Text"]:SetText("Power bar width: " .. (c.bars[2].width or 150))
    end
    if r.rageHeightSlider then r.rageHeightSlider:SetValue(c.bars[2].height or DEFAULT_CONFIG.bars[2].height) end
    if r.powerBgColorBtn and r.powerBgColorBtn.update then r.powerBgColorBtn.update() end
    if r.powerBgAlphaSlider then
        local v = c.bars[2].bgAlpha
        if v == nil then v = DEFAULT_CONFIG.bars[2].bgAlpha or 0 end
        r.powerBgAlphaSlider:SetValue(v)
        _G[r.powerBgAlphaSlider:GetName() .. "Text"]:SetText("Backdrop transparency: " .. v .. "%")
    end
    if r.absorbWidthSlider and c.bars[3] then
        r.absorbWidthSlider:SetValue(c.bars[3].width or DEFAULT_CONFIG.bars[3].width or 150)
        _G[r.absorbWidthSlider:GetName() .. "Text"]:SetText("Shield pool bar width: " .. (c.bars[3].width or 150))
    end
    if r.absorbHeightSlider and c.bars[3] then r.absorbHeightSlider:SetValue(c.bars[3].height or DEFAULT_CONFIG.bars[3].height) end
    if r.absorbBgColorBtn and r.absorbBgColorBtn.update then r.absorbBgColorBtn.update() end
    if r.absorbBgAlphaSlider and c.bars[3] then
        local v = c.bars[3].bgAlpha
        if v == nil then v = DEFAULT_CONFIG.bars[3].bgAlpha or 0 end
        r.absorbBgAlphaSlider:SetValue(v)
        _G[r.absorbBgAlphaSlider:GetName() .. "Text"]:SetText("Backdrop transparency: " .. v .. "%")
    end
    if r.markerValueSlider and c.bars and c.bars[2] then
        local v = c.bars[2].markerValue or c.bars[2].markerPercent or 30
        r.markerValueSlider:SetValue(v)
        _G[r.markerValueSlider:GetName() .. "Text"]:SetText("Resource value: " .. v .. " (e.g. 30 rage)")
    end
    if r.absorbMaxPercentSlider and c.bars and c.bars[3] then
        local v = c.bars[3].absorbMaxPercent or DEFAULT_CONFIG.bars[3].absorbMaxPercent or 30
        r.absorbMaxPercentSlider:SetValue(v)
        _G[r.absorbMaxPercentSlider:GetName() .. "Text"]:SetText(v .. "% of max health (30% for Warrior Ignore Pain)")
    end

    if r.healthBarColorBtn and r.healthBarColorBtn.update then r.healthBarColorBtn.update() end
    if r.rageBarColorBtn and r.rageBarColorBtn.update then r.rageBarColorBtn.update() end
    if r.markerColorBtn and r.markerColorBtn.update then r.markerColorBtn.update() end
    if r.absorbColorBtn and r.absorbColorBtn.update then r.absorbColorBtn.update() end

    if r.powerTypeDropdown and r.POWER_OPTIONS then
        local currentPower = TerninUI_Config.bars[2].resource or "rage"
        UIDropDownMenu_SetSelectedValue(r.powerTypeDropdown, currentPower)
        for _, opt in ipairs(r.POWER_OPTIONS) do
            if opt.value == currentPower then
                if UIDropDownMenu_SetText then UIDropDownMenu_SetText(r.powerTypeDropdown, opt.text) end
                break
            end
        end
    end

    LayoutBars()
end

if C_Timer and C_Timer.After then
    C_Timer.After(0, OptionsRefresh)
else
    OptionsRefresh()
end

------------------------------------------------------------
-- Standalone config window
------------------------------------------------------------

local CONFIG_FRAME_W = 440
local CONFIG_FRAME_H = 600
local CONFIG_PAD = 20
local SCROLLBAR_W = 26

local configFrame = CreateFrame("Frame", "TerninUI_ConfigFrame", UIParent)
configFrame:SetSize(CONFIG_FRAME_W, CONFIG_FRAME_H)
configFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
configFrame:SetMovable(true)
configFrame:EnableMouse(true)
configFrame:RegisterForDrag("LeftButton")
configFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
configFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
configFrame:SetFrameStrata("DIALOG")
configFrame:Hide()
if configFrame.SetClipsChildren then
    configFrame:SetClipsChildren(true)
end

local configBg = configFrame:CreateTexture(nil, "BACKGROUND")
configBg:SetColorTexture(0.12, 0.12, 0.12, 0.98)
configBg:SetAllPoints(configFrame)

local configTitle = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
configTitle:SetPoint("TOPLEFT", configFrame, "TOPLEFT", CONFIG_PAD, -14)
configTitle:SetPoint("RIGHT", configFrame, "RIGHT", -CONFIG_PAD - 32, 0)
configTitle:SetText("TerninUI Options")
configTitle:SetJustifyH("CENTER")

local configClose = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
configClose:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -CONFIG_PAD, -CONFIG_PAD)

local configScroll = CreateFrame("ScrollFrame", "TerninUI_ConfigScroll", configFrame, "UIPanelScrollFrameTemplate")
configScroll:SetPoint("TOPLEFT", configFrame, "TOPLEFT", CONFIG_PAD, -48)
configScroll:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -CONFIG_PAD - SCROLLBAR_W, CONFIG_PAD)
if configScroll.SetClipsChildren then
    configScroll:SetClipsChildren(true)
end

local scrollViewportW = CONFIG_FRAME_W - 2 * CONFIG_PAD - SCROLLBAR_W
local contentW = scrollViewportW - 16
local configContent = CreateFrame("Frame", nil, configScroll)
configContent:SetSize(contentW, 800)
configScroll:SetScrollChild(configContent)

local function ShowTerninUIConfig()
    if optionsContent then
        optionsContent:SetParent(configContent)
        optionsContent:ClearAllPoints()
        optionsContent:SetPoint("TOPLEFT", configContent, "TOPLEFT", 0, 0)
        optionsContent:SetPoint("RIGHT", configContent, "RIGHT", 0, 0)
        optionsContent:SetHeight(OPTIONS_CONTENT_H)
        optionsContent:Show()
        OptionsRefresh()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, OptionsRefresh)
        end
    end
    configFrame:Show()
end

local function HideTerninUIConfig()
    configFrame:Hide()
    if optionsContent and optionsWrapper and optionsWrapper.scroll then
        optionsContent:SetParent(optionsWrapper.scroll)
        optionsContent:ClearAllPoints()
        optionsContent:SetPoint("TOPLEFT", 0, 0)
        optionsContent:SetPoint("RIGHT", 0, 0)
        optionsContent:SetHeight(OPTIONS_CONTENT_H)
        optionsWrapper.scroll:SetScrollChild(optionsContent)
    end
end

configClose:SetScript("OnClick", HideTerninUIConfig)

-- ---------------------------------------------------------------------------
-- Slash command: /tui [lock|unlock]
-- ---------------------------------------------------------------------------

SLASH_TERNINUI1 = "/tui"
SlashCmdList["TERNINUI"] = function(msg)
    msg = (msg or ""):lower():trim()

    if msg == "lock" then
        TerninUI_Config.locked = true
        ApplyLockState()
        print("|cFF00A2FFTerninUI:|r Bars locked.")
    elseif msg == "unlock" then
        TerninUI_Config.locked = false
        ApplyLockState()
        print("|cFF00A2FFTerninUI:|r Bars unlocked. Drag to move.")
    else
        if terninUICategory and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(terninUICategory:GetID())
        elseif optionsWrapper and InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(optionsWrapper)
        else
            ShowTerninUIConfig()
        end
    end
end

print("|cFF00A2FFTerninUI:|r Loaded. Type |cFFFFFFFF/tui|r to open options. Drag the bars to move.")
