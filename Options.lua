local ADDON_NAME, ns = ...
local DEFAULT_CONFIG = ns.DEFAULT_CONFIG
local CopyTable = ns.CopyTable
local LayoutBars = ns.LayoutBars
local UpdateAllBars = ns.UpdateAllBars
local ApplyLockState = ns.ApplyLockState
local LayoutExtraButtons = ns.LayoutExtraButtons
local barFrames = ns.barFrames

local PAD = 24
local OPTIONS_CONTENT_H = 950

------------------------------------------------------------
-- UI helpers
------------------------------------------------------------

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

    local widthSlider = CreateFrame("Slider", "$parent_BarWidth", panel, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", lockCheck, "BOTTOMLEFT", 0, -22)
    widthSlider:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    widthSlider:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    widthSlider:SetMinMaxValues(150, 500)
    widthSlider:SetValueStep(10)
    _G[widthSlider:GetName() .. "Low"]:SetText("150")
    _G[widthSlider:GetName() .. "High"]:SetText("500")
    _G[widthSlider:GetName() .. "Text"]:SetText("Bar width")
    widthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        TerninUI_Config.barWidth = value
        _G[self:GetName() .. "Text"]:SetText("Bar width: " .. value)
        LayoutBars()
    end)
    widthSlider:SetValue(TerninUI_Config.barWidth or DEFAULT_CONFIG.barWidth)
    _G[widthSlider:GetName() .. "Text"]:SetText("Bar width: " .. (TerninUI_Config.barWidth or DEFAULT_CONFIG.barWidth))
    CleanSliderStyle(widthSlider)
    optionsRefs.widthSlider = widthSlider

    local spacingSlider = CreateFrame("Slider", "$parent_BarSpacing", panel, "OptionsSliderTemplate")
    spacingSlider:SetPoint("TOPLEFT", widthSlider, "BOTTOMLEFT", 0, -44)
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

    local line2 = AddSectionLine(panel, spacingSlider)

    local backdropHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    backdropHeader:SetPoint("TOPLEFT", line2, "BOTTOMLEFT", 0, -20)
    backdropHeader:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    backdropHeader:SetText("Backdrop (bar background)")
    backdropHeader:SetTextColor(1, 0.82, 0)

    local globalBgColorRow = CreateFrame("Frame", nil, panel)
    globalBgColorRow:SetPoint("TOPLEFT", backdropHeader, "BOTTOMLEFT", 0, -14)
    globalBgColorRow:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    globalBgColorRow:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    globalBgColorRow:SetHeight(24)
    local globalBgColorBtn = CreateFrame("Button", nil, globalBgColorRow)
    globalBgColorBtn:SetSize(20, 20)
    globalBgColorBtn:SetPoint("LEFT", globalBgColorRow, "LEFT", 0, 0)
    local bgColorLabel = globalBgColorRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    bgColorLabel:SetPoint("LEFT", globalBgColorBtn, "RIGHT", 8, 0)
    bgColorLabel:SetText("Background color")
    bgColorLabel:SetTextColor(1, 0.82, 0)
    globalBgColorBtn.tex = globalBgColorBtn:CreateTexture(nil, "BACKGROUND")
    globalBgColorBtn.tex:SetAllPoints(true)
    if globalBgColorBtn.SetBackdrop then
        globalBgColorBtn:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        globalBgColorBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    end
    local function updateGlobalBgSwatch()
        local c = TerninUI_Config.globalBgColor or DEFAULT_CONFIG.globalBgColor
        globalBgColorBtn.tex:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, 1)
    end
    globalBgColorBtn.update = updateGlobalBgSwatch
    globalBgColorBtn:SetScript("OnClick", function()
        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            local c = TerninUI_Config.globalBgColor or DEFAULT_CONFIG.globalBgColor
            local r, g, b, a = c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
            ColorPickerFrame.previousValues = { r = r, g = g, b = b, a = a }
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b, opacity = a or 1, hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or 1
                    TerninUI_Config.globalBgColor = { nr, ng, nb, na or 1 }
                    updateGlobalBgSwatch()
                    LayoutBars()
                end,
                cancelFunc = function()
                    local prev = ColorPickerFrame.previousValues
                    if prev then
                        TerninUI_Config.globalBgColor = { prev.r or 1, prev.g or 1, prev.b or 1, prev.a or 1 }
                        updateGlobalBgSwatch()
                        LayoutBars()
                    end
                end
            })
        end
    end)
    updateGlobalBgSwatch()
    optionsRefs.globalBgColorBtn = globalBgColorBtn

    local alphaSlider = CreateFrame("Slider", "$parent_GlobalBgAlpha", panel, "OptionsSliderTemplate")
    alphaSlider:SetPoint("TOPLEFT", globalBgColorRow, "BOTTOMLEFT", 0, -28)
    alphaSlider:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    alphaSlider:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    alphaSlider:SetMinMaxValues(0, 100)
    alphaSlider:SetValueStep(5)
    _G[alphaSlider:GetName() .. "Low"]:SetText("0%")
    _G[alphaSlider:GetName() .. "High"]:SetText("100%")
    _G[alphaSlider:GetName() .. "Text"]:SetText("Transparency")
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        TerninUI_Config.globalBgAlpha = value
        _G[self:GetName() .. "Text"]:SetText("Transparency: " .. value .. "%")
        LayoutBars()
    end)
    do
        local v = TerninUI_Config.globalBgAlpha
        if v == nil then v = DEFAULT_CONFIG.globalBgAlpha end
        alphaSlider:SetValue(v)
        _G[alphaSlider:GetName() .. "Text"]:SetText("Transparency: " .. v .. "%")
    end
    CleanSliderStyle(alphaSlider)
    optionsRefs.alphaSlider = alphaSlider
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

    local healthHeightSlider = CreateHeightSlider(panel, 1, healthCheck, "Health bar")
    optionsRefs.healthHeightSlider = healthHeightSlider

    local healthBarColorBtn = CreateColorOption(panel, healthHeightSlider, "Health bar color", function()
        return TerninUI_Config.bars[1].color or DEFAULT_CONFIG.bars[1].color
    end, function(r, g, b, a)
        TerninUI_Config.bars[1].color = { r, g, b, a }
        if barFrames[1] then barFrames[1]:SetStatusBarColor(r, g, b, a) end
    end)
    optionsRefs.healthBarColorBtn = healthBarColorBtn
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

    local rageHeightSlider = CreateHeightSlider(panel, 2, rageCheck, "Power bar")
    optionsRefs.rageHeightSlider = rageHeightSlider

    local markerEnabledCheck = CreateEnableCheckbox(panel, rageHeightSlider, "Enable marker",
        function() return TerninUI_Config.bars[2].markerEnabled == true end,
        function(enabled)
            TerninUI_Config.bars[2].markerEnabled = enabled
            LayoutBars()
            UpdateAllBars("UNIT_POWER_UPDATE", "player")
        end)
    optionsRefs.markerEnabledCheck = markerEnabledCheck

    local markerValueRow = CreateFrame("Frame", nil, panel)
    markerValueRow:SetPoint("TOPLEFT", markerEnabledCheck, "BOTTOMLEFT", 0, -14)
    markerValueRow:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    markerValueRow:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    markerValueRow:SetHeight(24)
    local markerEdit = CreateFrame("EditBox", "$parent_PowerMarkerValue", markerValueRow, "InputBoxTemplate")
    markerEdit:SetSize(50, 20)
    markerEdit:SetPoint("LEFT", markerValueRow, "LEFT", 0, 0)
    local markerValueLabel = markerValueRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    markerValueLabel:SetPoint("LEFT", markerEdit, "RIGHT", 8, 0)
    markerValueLabel:SetText("Resource value (e.g. 30 rage)")
    markerValueLabel:SetTextColor(1, 0.82, 0)
    markerEdit:SetAutoFocus(false)
    markerEdit:SetMaxLetters(4)
    markerEdit:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v and v >= 0 then
            TerninUI_Config.bars[2].markerValue = v
            LayoutBars()
            UpdateAllBars("UNIT_POWER_UPDATE", "player")
        end
        self:ClearFocus()
    end)
    markerEdit:SetScript("OnEditFocusLost", function(self)
        local v = tonumber(self:GetText())
        if v and v >= 0 then
            TerninUI_Config.bars[2].markerValue = v
            LayoutBars()
            UpdateAllBars("UNIT_POWER_UPDATE", "player")
        end
    end)
    markerEdit:SetText(tostring(TerninUI_Config.bars[2].markerValue or TerninUI_Config.bars[2].markerPercent or 30))
    optionsRefs.markerEdit = markerEdit

    local markerColorRow = CreateFrame("Frame", nil, panel)
    markerColorRow:SetPoint("TOPLEFT", markerValueRow, "BOTTOMLEFT", 0, -14)
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
end

local function BuildAbsorbPanel(panel)
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -16)
    header:SetText("Shield Pool")
    header:SetTextColor(1, 0.82, 0)

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    hint:SetText("Shows your total absorb shield pool (Ignore Pain, Power Word: Shield, etc.)")
    hint:SetTextColor(0.7, 0.7, 0.7)

    local absorbCheck = CreateEnableCheckbox(panel, hint, "Enable Shield Pool",
        function() return TerninUI_Config.bars[3].enabled ~= false end,
        function(enabled)
            TerninUI_Config.bars[3].enabled = enabled
            LayoutBars()
            UpdateAllBars("UNIT_ABSORB_AMOUNT_CHANGED", "player")
        end)
    optionsRefs.absorbCheck = absorbCheck

    local absorbHeightSlider = CreateHeightSlider(panel, 3, absorbCheck, "Shield pool bar")
    optionsRefs.absorbHeightSlider = absorbHeightSlider

    local absorbColorBtn = CreateColorOption(panel, absorbHeightSlider, "Shield pool bar color", function()
        return TerninUI_Config.bars[3].color or DEFAULT_CONFIG.bars[3].color
    end, function(r, g, b, a)
        TerninUI_Config.bars[3].color = { r, g, b, a }
        if barFrames[3] then barFrames[3]:SetStatusBarColor(r, g, b, a) end
    end)
    optionsRefs.absorbColorBtn = absorbColorBtn
end

local function BuildExtraButtonsPanel(panel)
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -16)
    header:SetText("Extra Buttons")
    header:SetTextColor(1, 0.82, 0)

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    hint:SetText("Track extra cooldowns by Spell ID. Drag to reposition when unlocked.")
    hint:SetTextColor(0.7, 0.7, 0.7)

    local ebCfg = TerninUI_Config.extraButtons or DEFAULT_CONFIG.extraButtons

    local ebCheck = CreateEnableCheckbox(panel, hint, "Enable Extra Buttons",
        function() return ebCfg.enabled ~= false end,
        function(enabled)
            TerninUI_Config.extraButtons.enabled = enabled
            LayoutExtraButtons()
        end)
    optionsRefs.ebCheck = ebCheck

    local sizeSlider = CreateFrame("Slider", "TerninUI_EBSizeSlider", panel, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", ebCheck, "BOTTOMLEFT", 0, -28)
    sizeSlider:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    sizeSlider:SetMinMaxValues(16, 64)
    sizeSlider:SetValueStep(1)
    local initSize = ebCfg.iconSize or 32
    sizeSlider:SetValue(initSize)
    _G[sizeSlider:GetName() .. "Low"]:SetText("16")
    _G[sizeSlider:GetName() .. "High"]:SetText("64")
    _G[sizeSlider:GetName() .. "Text"]:SetText("Icon size: " .. initSize)
    sizeSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val + 0.5)
        TerninUI_Config.extraButtons.iconSize = val
        _G[self:GetName() .. "Text"]:SetText("Icon size: " .. val)
        LayoutExtraButtons()
    end)
    CleanSliderStyle(sizeSlider)
    optionsRefs.ebSizeSlider = sizeSlider

    local spacingSlider = CreateFrame("Slider", "TerninUI_EBSpacingSlider", panel, "OptionsSliderTemplate")
    spacingSlider:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -28)
    spacingSlider:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    spacingSlider:SetMinMaxValues(0, 10)
    spacingSlider:SetValueStep(1)
    local initSpacing = ebCfg.spacing or 2
    spacingSlider:SetValue(initSpacing)
    _G[spacingSlider:GetName() .. "Low"]:SetText("0")
    _G[spacingSlider:GetName() .. "High"]:SetText("10")
    _G[spacingSlider:GetName() .. "Text"]:SetText("Icon spacing: " .. initSpacing)
    spacingSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val + 0.5)
        TerninUI_Config.extraButtons.spacing = val
        _G[self:GetName() .. "Text"]:SetText("Icon spacing: " .. val)
        LayoutExtraButtons()
    end)
    CleanSliderStyle(spacingSlider)
    optionsRefs.ebSpacingSlider = spacingSlider

    local listLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    listLabel:SetPoint("TOPLEFT", spacingSlider, "BOTTOMLEFT", 0, -20)
    listLabel:SetText("Spell IDs")
    listLabel:SetTextColor(1, 0.82, 0)

    local addRow = CreateFrame("Frame", nil, panel)
    addRow:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -8)
    addRow:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    addRow:SetHeight(26)

    local addBox = CreateFrame("EditBox", "TerninUI_EBAddSpellID", addRow, "InputBoxTemplate")
    addBox:SetPoint("LEFT", addRow, "LEFT", 6, 0)
    addBox:SetSize(120, 22)
    addBox:SetAutoFocus(false)
    addBox:SetNumeric(true)
    addBox:SetMaxLetters(10)

    local addBtn = CreateFrame("Button", nil, addRow, "UIPanelButtonTemplate")
    addBtn:SetPoint("LEFT", addBox, "RIGHT", 8, 0)
    addBtn:SetSize(60, 22)
    addBtn:SetText("Add")

    local listArea = CreateFrame("Frame", nil, panel)
    listArea:SetPoint("TOPLEFT", addRow, "BOTTOMLEFT", 0, -8)
    listArea:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    listArea:SetHeight(200)
    optionsRefs.ebListArea = listArea

    local listRows = {}
    optionsRefs.ebListRows = listRows

    local function RefreshSpellList()
        local cfg = TerninUI_Config.extraButtons or DEFAULT_CONFIG.extraButtons
        local spellIDs = cfg.spellIDs or {}
        for _, row in ipairs(listRows) do row:Hide() end

        for i, sid in ipairs(spellIDs) do
            local row = listRows[i]
            if not row then
                row = CreateFrame("Frame", nil, listArea)
                row:SetHeight(22)
                row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
                row.removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.removeBtn:SetSize(18, 18)
                row.removeBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                row.removeBtn:SetText("X")
                row.removeBtn:SetNormalFontObject("GameFontHighlightSmall")
                listRows[i] = row
            end

            row:SetPoint("TOPLEFT", listArea, "TOPLEFT", 0, -((i - 1) * 24))
            row:SetPoint("RIGHT", listArea, "RIGHT", 0, 0)

            local name = ""
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(sid)
            if info and info.name then
                name = info.name
            elseif GetSpellInfo then
                name = GetSpellInfo(sid) or ""
            end
            row.text:SetText(sid .. " - " .. name)

            row.removeBtn:SetScript("OnClick", function()
                if TerninUI_Config.extraButtons and TerninUI_Config.extraButtons.spellIDs then
                    table.remove(TerninUI_Config.extraButtons.spellIDs, i)
                end
                RefreshSpellList()
                LayoutExtraButtons()
            end)
            row:Show()
        end
    end

    addBtn:SetScript("OnClick", function()
        local text = addBox:GetText()
        local sid = tonumber(text)
        if sid and sid > 0 then
            if not TerninUI_Config.extraButtons then
                TerninUI_Config.extraButtons = CopyTable(DEFAULT_CONFIG.extraButtons)
            end
            if not TerninUI_Config.extraButtons.spellIDs then
                TerninUI_Config.extraButtons.spellIDs = {}
            end
            table.insert(TerninUI_Config.extraButtons.spellIDs, sid)
            addBox:SetText("")
            RefreshSpellList()
            LayoutExtraButtons()
        end
    end)

    addBox:SetScript("OnEnterPressed", function(self)
        addBtn:Click()
    end)

    optionsRefs.ebRefreshList = RefreshSpellList
    RefreshSpellList()
end

------------------------------------------------------------
-- Settings registration
------------------------------------------------------------

local healthWrapper, powerWrapper, buffBarsWrapper, extraBtnWrapper
local optionsWrapper, optionsContent

local terninUICategory
if Settings and Settings.RegisterCanvasLayoutSubcategory then
    local parentFrame = CreateFrame("Frame", "TerninUI_Parent", UIParent)
    parentFrame.name = "TerninUI"

    local parentScroll = CreateFrame("ScrollFrame", "TerninUI_ParentScroll", parentFrame, "UIPanelScrollFrameTemplate")
    parentScroll:SetPoint("TOPLEFT", 0, 0)
    parentScroll:SetPoint("BOTTOMRIGHT", 0, 0)
    local parentContent = CreateFrame("Frame", nil, parentScroll)
    parentContent:SetSize(400, 320)
    parentScroll:SetScrollChild(parentContent)
    parentFrame.content = parentContent

    healthWrapper = CreateSubcategoryWrapper("HealthBar", 220)
    powerWrapper = CreateSubcategoryWrapper("PowerBar", 320)
    buffBarsWrapper = CreateSubcategoryWrapper("BuffBars", 280)
    extraBtnWrapper = CreateSubcategoryWrapper("ExtraButtons", 600)

    for _, w in ipairs({ parentFrame, healthWrapper, powerWrapper, buffBarsWrapper, extraBtnWrapper }) do
        w:SetScript("OnShow", OptionsRefresh)
    end

    BuildDefaultBarsPanel(parentContent)
    BuildHealthPanel(healthWrapper.content)
    BuildPowerPanel(powerWrapper.content)
    BuildAbsorbPanel(buffBarsWrapper.content)
    BuildExtraButtonsPanel(extraBtnWrapper.content)

    terninUICategory = Settings.RegisterCanvasLayoutCategory(parentFrame, "TerninUI")
    Settings.RegisterCanvasLayoutSubcategory(terninUICategory, healthWrapper, "Health Bar")
    Settings.RegisterCanvasLayoutSubcategory(terninUICategory, powerWrapper, "Power Bar")
    Settings.RegisterCanvasLayoutSubcategory(terninUICategory, buffBarsWrapper, "Shield Pool")
    Settings.RegisterCanvasLayoutSubcategory(terninUICategory, extraBtnWrapper, "Extra Buttons")
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
    defaultBarsContent:SetHeight(320)
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

    local extraBtnContent = CreateFrame("Frame", nil, optionsContent)
    extraBtnContent:SetPoint("TOPLEFT", buffBarsContent, "BOTTOMLEFT", 0, -20)
    extraBtnContent:SetPoint("RIGHT", optionsContent, "RIGHT", 0, 0)
    extraBtnContent:SetHeight(400)
    BuildExtraButtonsPanel(extraBtnContent)

    optionsWrapper:SetScript("OnShow", function()
        local w = optionsWrapper:GetWidth()
        if w and w > 0 then optionsContent:SetWidth(w - 30) end
        OptionsRefresh()
    end)
    optionsWrapper:SetScript("OnSizeChanged", function()
        local w = optionsWrapper:GetWidth()
        if w and w > 0 then optionsContent:SetWidth(w - 30) end
    end)
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsWrapper)
    end
end

------------------------------------------------------------
-- Options refresh
------------------------------------------------------------

function OptionsRefresh()
    local c = TerninUI_Config
    local r = optionsRefs
    if r.lockCheck and r.lockCheck.SetChecked then r.lockCheck:SetChecked(c.locked) end
    if r.widthSlider then
        r.widthSlider:SetValue(c.barWidth or DEFAULT_CONFIG.barWidth)
        _G[r.widthSlider:GetName() .. "Text"]:SetText("Bar width: " .. (c.barWidth or DEFAULT_CONFIG.barWidth))
    end
    if r.spacingSlider then
        r.spacingSlider:SetValue(c.barSpacing or DEFAULT_CONFIG.barSpacing)
        _G[r.spacingSlider:GetName() .. "Text"]:SetText("Bar spacing: " .. (c.barSpacing or DEFAULT_CONFIG.barSpacing))
    end
    if r.alphaSlider then
        local aVal = c.globalBgAlpha
        if aVal == nil then aVal = DEFAULT_CONFIG.globalBgAlpha end
        r.alphaSlider:SetValue(aVal)
        _G[r.alphaSlider:GetName() .. "Text"]:SetText("Transparency: " .. aVal .. "%")
    end
    if r.globalBgColorBtn and r.globalBgColorBtn.update then r.globalBgColorBtn.update() end

    if r.healthCheck and r.healthCheck.SetChecked then r.healthCheck:SetChecked(c.bars[1].enabled ~= false) end
    if r.rageCheck and r.rageCheck.SetChecked then r.rageCheck:SetChecked(c.bars[2].enabled ~= false) end
    if r.markerEnabledCheck and r.markerEnabledCheck.SetChecked then r.markerEnabledCheck:SetChecked(c.bars[2].markerEnabled == true) end
    if r.absorbCheck and r.absorbCheck.SetChecked then r.absorbCheck:SetChecked(c.bars[3] and c.bars[3].enabled ~= false) end

    if r.healthHeightSlider then r.healthHeightSlider:SetValue(c.bars[1].height or DEFAULT_CONFIG.bars[1].height) end
    if r.rageHeightSlider then r.rageHeightSlider:SetValue(c.bars[2].height or DEFAULT_CONFIG.bars[2].height) end
    if r.absorbHeightSlider and c.bars[3] then r.absorbHeightSlider:SetValue(c.bars[3].height or DEFAULT_CONFIG.bars[3].height) end
    if r.markerEdit then r.markerEdit:SetText(tostring(c.bars[2].markerValue or c.bars[2].markerPercent or 30)) end

    if r.healthBarColorBtn and r.healthBarColorBtn.update then r.healthBarColorBtn.update() end
    if r.rageBarColorBtn and r.rageBarColorBtn.update then r.rageBarColorBtn.update() end
    if r.markerColorBtn and r.markerColorBtn.update then r.markerColorBtn.update() end
    if r.absorbColorBtn and r.absorbColorBtn.update then r.absorbColorBtn.update() end

    local ebCfg = c.extraButtons or DEFAULT_CONFIG.extraButtons
    if r.ebCheck and r.ebCheck.SetChecked then r.ebCheck:SetChecked(ebCfg.enabled ~= false) end
    if r.ebSizeSlider then r.ebSizeSlider:SetValue(ebCfg.iconSize or 32) end
    if r.ebSpacingSlider then r.ebSpacingSlider:SetValue(ebCfg.spacing or 2) end
    if r.ebRefreshList then r.ebRefreshList() end

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

------------------------------------------------------------
-- Slash command
------------------------------------------------------------

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
            InterfaceOptionsFrame_OpenToCategory(optionsWrapper)
        else
            ShowTerninUIConfig()
        end
    end
end

print("|cFF00A2FFTerninUI:|r Loaded. Type |cFFFFFFFF/tui|r to open options. Drag the bars to move.")
