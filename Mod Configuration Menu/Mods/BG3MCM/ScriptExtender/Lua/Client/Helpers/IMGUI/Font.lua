Font = {}

-- Key-value map of logical size -> numeric value (px)
-- These are also BG3SE's built-in font names; the engine's implicit default is Medium, not Default.
Font.FONT_SIZE_OPTIONS = {
    Tiny = 24.0,
    Small = 28.0,
    Medium = 32.0,
    Default = 36.0,
    Large = 40.0,
    Big = 44.0
}

-- Stable order for stepping operations (smallest to largest)
local FONT_SIZE_ORDER = { "Tiny", "Small", "Medium", "Default", "Large", "Big" }

-- BG3SE loads only these built-in entries for languages with large glyph sets (IMGUIManager::InitializeUI)
local REDUCED_ATLAS_SIZE_ORDER = { "Medium", "Default", "Large" }
local REDUCED_ATLAS_LANGUAGES = { Japanese = true, Chinese = true, ChineseTraditional = true }

-- Font definitions: typeface -> file path
-- The empty typeface makes BG3SE load its native, language-specific font and glyph ranges.
local FONT_DEFINITIONS = {
    [""] = "",
    ["Inter-Regular"] = "Mods/BG3MCM/Assets/Fonts/Inter/Inter-Regular.ttf",
    ["OpenDyslexic"] = "Mods/BG3MCM/Assets/Fonts/OpenDyslexic/OpenDyslexic.ttf",
}

---@class AppliedGlobalFont
---@field typeface string FONT_DEFINITIONS key
---@field sizeKey string FONT_SIZE_OPTIONS key

-- Restore target for a failed load when this Lua context has not applied a font yet (the setting defaults)
---@type AppliedGlobalFont
local NATIVE_BASELINE = { typeface = "", sizeKey = "Default" }

-- Last font fully applied to the built-in entries in this Lua context
---@type AppliedGlobalFont|nil
local appliedFont = nil

-- Helpers
local function _normalizeSizeKey(fontSize)
    if fontSize == nil then return nil end
    local t = type(fontSize)
    if t == "number" then
        -- If a raw number is provided, try to map it back to a key
        for k, v in pairs(Font.FONT_SIZE_OPTIONS) do
            if v == fontSize then
                return k
            end
        end
        return nil
    end

    local s = tostring(fontSize)
    -- Accept both TitleCase ("Tiny") and lowercase ("tiny")
    s = string.lower(s)
    return VCString.ToTitleCase(s)
end

function Font.GetFontSizeOptions()
    local out = {}
    for _, key in ipairs(FONT_SIZE_ORDER) do
        out[#out + 1] = VCString.ToTitleCase(key)
    end
    return out
end

function Font.IsValidFontSize(fontSize)
    return Font.GetSizeKey(fontSize) ~= nil
end

--- Return the built-in font name for a size, or nil if the size is unknown
---@param fontSize string|number|nil The font size key (e.g., "Default", "large") or its pixel value
---@return string|nil
function Font.GetSizeKey(fontSize)
    local key = _normalizeSizeKey(fontSize)
    if key and Font.FONT_SIZE_OPTIONS[key] then
        return key
    end
    return nil
end

function Font.GetSizeValue(fontSize)
    local key = Font.GetSizeKey(fontSize)
    if key then
        return Font.FONT_SIZE_OPTIONS[key]
    end

    if type(fontSize) == "number" then
        return fontSize
    end
    return nil
end

---@return string[]
local function getBuiltinSizeOrder()
    if REDUCED_ATLAS_LANGUAGES[Ext.Utils.GetGlobalSwitches().Language] then
        return REDUCED_ATLAS_SIZE_ORDER
    end
    return FONT_SIZE_ORDER
end

---@param font AppliedGlobalFont
---@return string
local function describeFont(font)
    local family = font.typeface == "" and "native" or font.typeface
    return string.format("%s/%s", family, font.sizeKey)
end

--- Load a font into every built-in entry at one size, stopping at the first failure
---@param font AppliedGlobalFont
---@return string|nil failedKey
local function loadBuiltinEntries(font)
    local fontPath = FONT_DEFINITIONS[font.typeface]
    local sizeValue = Font.FONT_SIZE_OPTIONS[font.sizeKey]
    for _, builtinName in ipairs(getBuiltinSizeOrder()) do
        if not Ext.IMGUI.LoadFont(builtinName, fontPath, sizeValue) then
            return builtinName
        end
    end
    return nil
end

--- Replace BG3SE's shared built-in fonts with one typeface at one size.
--- Every built-in name then refers to the same family and size, so this reaches every IMGUI window that uses the built-in fonts, including other mods' windows.
--- Fonts that other mods load under their own names are not changed.
--- On partial failure, restores the last fully applied font (NATIVE_BASELINE if none).
---@param typeface string|nil A FONT_DEFINITIONS key; nil or "" selects the native font
---@param fontSize string|number|nil A FONT_SIZE_OPTIONS key or its pixel value
---@return boolean success
---@return string|nil errorMessage
function Font.ApplyGlobalFont(typeface, fontSize)
    typeface = typeface or ""
    if not FONT_DEFINITIONS[typeface] then
        return false, string.format("Unknown font typeface '%s'", tostring(typeface))
    end
    local sizeKey = Font.GetSizeKey(fontSize)
    if not sizeKey then
        return false, string.format("Unknown font size '%s'", tostring(fontSize))
    end

    local font = { typeface = typeface, sizeKey = sizeKey }
    local failedKey = loadBuiltinEntries(font)
    if not failedKey then
        appliedFont = font
        return true, nil
    end

    local message = string.format("Failed to load font '%s' for built-in font '%s'", describeFont(font), failedKey)
    local previousFont = appliedFont or NATIVE_BASELINE
    local restoreFailedKey = loadBuiltinEntries(previousFont)
    if restoreFailedKey then
        appliedFont = nil
        return false, string.format("%s; restoring font '%s' also failed at '%s'",
            message, describeFont(previousFont), restoreFailedKey)
    end

    appliedFont = previousFont
    return false, string.format("%s; restored font '%s'", message, describeFont(previousFont))
end
