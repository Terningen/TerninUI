local ADDON_NAME, ns = ...

ns.PLAYER_UNIT = "player"

------------------------------------------------------------
-- Default configuration
------------------------------------------------------------

ns.DEFAULT_CONFIG = {
    locked = false,
    barWidth = 150,
    barSpacing = 0,
    globalBgColor = {0, 0, 0, 1},
    globalBgAlpha = 0,
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
            enabled = true,
        },
        {
            id = "power",
            type = "resource",
            resource = "rage",
            label = "Rage",
            color = {0.9, 0.1, 0.1, 1},
            height = 10,
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
            enabled = true,
        },
    },
    extraButtons = {
        enabled = true,
        iconSize = 32,
        spacing = 2,
        spellIDs = {},
        position = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = -160,
        },
    },
}

------------------------------------------------------------
-- Utility functions
------------------------------------------------------------

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

------------------------------------------------------------
-- Saved variable initialization
------------------------------------------------------------

if type(TerninUI_Config) ~= "table" then
    TerninUI_Config = ns.CopyTable(ns.DEFAULT_CONFIG)
else
    ns.MergeDefaults(TerninUI_Config, ns.DEFAULT_CONFIG)
end

local function EnsureBars()
    local defaults = ns.DEFAULT_CONFIG.bars
    local bars = TerninUI_Config.bars
    if #bars > 3 then
        for i = 4, #bars do bars[i] = nil end
    end
    for i = 1, 3 do
        if not bars[i] then
            bars[i] = ns.CopyTable(defaults[i] or defaults[1])
        else
            ns.MergeDefaults(bars[i], defaults[i] or defaults[1])
        end
    end
    if bars[3] and bars[3].type == "buff" then
        bars[3] = ns.CopyTable(defaults[3])
    end
    if not TerninUI_Config.extraButtons then
        TerninUI_Config.extraButtons = ns.CopyTable(ns.DEFAULT_CONFIG.extraButtons)
    else
        ns.MergeDefaults(TerninUI_Config.extraButtons, ns.DEFAULT_CONFIG.extraButtons)
    end
end
EnsureBars()

local b2 = TerninUI_Config.bars[2]
if b2 then
    if b2.markerValue == nil and b2.markerPercent then
        b2.markerValue = b2.markerPercent
    end
    if b2.markerEnabled == nil and b2.markerUseValue == true then
        b2.markerEnabled = true
    end
end
