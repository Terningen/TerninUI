--[[
    TerninUI - Core
    Addon namespace, default config, and saved variable initialization.
]]

local ADDON_NAME, ns = ...

ns.PLAYER_UNIT = "player"

-- ---------------------------------------------------------------------------
-- Default configuration
-- ---------------------------------------------------------------------------

ns.DEFAULT_CONFIG = {
    locked = false,
    barSpacing = 0,
    barStyle = "plain",
    gradientMode = "none",
    gradientIntensity = 30,
    position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -100,
    },
    bars = {
        {
            id = "health",
            type = "resource",
            resource = "health",
            label = "Health Bar",
            color = { 0.1, 0.8, 0.1, 1 },
            height = 10,
            width = 150,
            bgColor = {0, 0, 0, 1},
            bgAlpha = 30,
            enabled = true,
        },
        {
            id = "power",
            type = "resource",
            resource = "rage",
            label = "Rage",
            color = {0.9, 0.1, 0.1, 1},
            height = 10,
            width = 150,
            bgColor = {0, 0, 0, 1},
            bgAlpha = 30,
            enabled = true,
            markerEnabled = false,
            markerValue = 30,
            markerColor = {1, 1, 1, 0.9},
        },
        {
            id = "absorb",
            type = "resource",
            resource = "absorb",
            label = "Shield Pool",
            color = {0.9, 0.85, 0.2, 1},
            height = 10,
            width = 150,
            bgColor = {0, 0, 0, 1},
            bgAlpha = 30,
            absorbMaxPercent = 30,
            enabled = true,
        },
    },
}

-- ---------------------------------------------------------------------------
-- Utilities
-- ---------------------------------------------------------------------------

function ns.CopyTable(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    local new = {}
    for k, v in pairs(tbl) do
        new[k] = ns.CopyTable(v)
    end
    return new
end

function ns.MergeDefaults(into, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(into[k]) ~= "table" then
                into[k] = ns.CopyTable(v)
            else
                ns.MergeDefaults(into[k], v)
            end
        elseif into[k] == nil then
            into[k] = v
        end
    end
end

-- ---------------------------------------------------------------------------
-- Saved variable initialization
-- ---------------------------------------------------------------------------

if type(TerninUI_Config) ~= "table" then
    TerninUI_Config = ns.CopyTable(ns.DEFAULT_CONFIG)
else
    ns.MergeDefaults(TerninUI_Config, ns.DEFAULT_CONFIG)
end

-- Ensure bars config exists and migrate from old formats.
local function EnsureBars()
    local defaults = ns.DEFAULT_CONFIG.bars
    local bars = TerninUI_Config.bars
    local oldBarWidth = TerninUI_Config.barWidth
    local oldBgColor = TerninUI_Config.globalBgColor
    local oldBgAlpha = TerninUI_Config.globalBgAlpha

    -- Cap at 3 bars
    if #bars > 3 then
        for i = 4, #bars do bars[i] = nil end
    end

    for i = 1, 3 do
        if not bars[i] then
            bars[i] = ns.CopyTable(defaults[i] or defaults[1])
        else
            -- Migrate legacy global settings to per-bar
            if oldBarWidth and bars[i].width == nil then bars[i].width = oldBarWidth end
            if oldBgColor and bars[i].bgColor == nil then bars[i].bgColor = oldBgColor end
            if oldBgAlpha ~= nil and bars[i].bgAlpha == nil then bars[i].bgAlpha = oldBgAlpha end
            ns.MergeDefaults(bars[i], defaults[i] or defaults[1])
        end
    end

    -- Reset absorb bar if it was the old buff type
    if bars[3] and bars[3].type == "buff" then
        bars[3] = ns.CopyTable(defaults[3])
    end
end
EnsureBars()

-- Migrate removed bar styles (raid -> plain)
if TerninUI_Config.barStyle == "raid" then
    TerninUI_Config.barStyle = "plain"
end

-- Migrate Power bar legacy fields
local powerBar = TerninUI_Config.bars[2]
if powerBar then
    if powerBar.markerValue == nil and powerBar.markerPercent then
        powerBar.markerValue = powerBar.markerPercent
    end
    if powerBar.markerEnabled == nil and powerBar.markerUseValue == true then
        powerBar.markerEnabled = true
    end
end
