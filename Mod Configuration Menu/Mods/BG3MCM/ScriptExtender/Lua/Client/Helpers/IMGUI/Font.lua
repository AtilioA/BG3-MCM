Font = {}

-- BG3SE's built-in font names and their own sizes in pixels; the engine's implicit default is Medium
local BUILTIN_FONTS = {
    { name = "Tiny",    size = 24.0 },
    { name = "Small",   size = 28.0 },
    { name = "Medium",  size = 32.0 },
    { name = "Default", size = 36.0 },
    { name = "Large",   size = 40.0 },
    { name = "Big",     size = 44.0 },
}

-- Font definitions: typeface -> file path
-- The empty typeface makes BG3SE load its native, language-specific font and glyph ranges.
local FONT_DEFINITIONS = {
    [""] = "",
    ["Inter-Regular"] = "Mods/BG3MCM/Assets/Fonts/Inter/Inter-Regular.ttf",
    ["OpenDyslexic"] = "Mods/BG3MCM/Assets/Fonts/OpenDyslexic/OpenDyslexic.ttf",
}

---@class AppliedGlobalFont
---@field typeface string FONT_DEFINITIONS key
---@field size number|nil Pixel size for every entry; nil keeps each entry at its own size

-- Restore target for a failed load when this Lua context has not applied a font yet: the engine's native fonts at their own sizes
---@type AppliedGlobalFont
local NATIVE_BASELINE = { typeface = "", size = nil }

-- Last font fully applied to the built-in entries in this Lua context
---@type AppliedGlobalFont|nil
local appliedFont = nil

---@param size any
---@return boolean
local function isValidSize(size)
    return type(size) == "number" and size > 0
end

--- Load MCM's own font, which only MCM windows use
---@param typeface string|nil A FONT_DEFINITIONS key; nil or "" selects the native font
---@param size number Pixel size
---@return boolean success
function Font.ApplyMCMFont(typeface, size)
    local path = FONT_DEFINITIONS[typeface or ""]
    if not path or not isValidSize(size) then
        return false
    end
    return Ext.IMGUI.LoadFont("BG3MCM_Font", path, size)
end

---@param font AppliedGlobalFont
---@return string
local function describeFont(font)
    local family = font.typeface == "" and "native" or font.typeface
    return string.format("%s/%s", family, font.size and tostring(font.size) or "own sizes")
end

--- Load a font into every built-in entry, stopping at the first failure
---@param font AppliedGlobalFont
---@return string|nil failedName
local function loadBuiltinEntries(font)
    local fontPath = FONT_DEFINITIONS[font.typeface]
    for _, builtin in ipairs(BUILTIN_FONTS) do
        if not Ext.IMGUI.LoadFont(builtin.name, fontPath, font.size or builtin.size) then
            return builtin.name
        end
    end
    return nil
end

--- Replace BG3SE's shared built-in fonts with one typeface, at one size or at each entry's own size.
--- This reaches every IMGUI window that uses the built-in fonts, including other mods' windows.
--- Fonts that other mods load under their own names are not changed.
--- On partial failure, restores the last fully applied font (NATIVE_BASELINE if none).
---@param typeface string|nil A FONT_DEFINITIONS key; nil or "" selects the native font
---@param size number|nil Pixel size; nil keeps each entry at its own size
---@return boolean success
---@return string|nil errorMessage
function Font.ApplyGlobalFont(typeface, size)
    typeface = typeface or ""
    if not FONT_DEFINITIONS[typeface] then
        return false, string.format("Unknown font typeface '%s'", tostring(typeface))
    end
    if size ~= nil and not isValidSize(size) then
        return false, string.format("Invalid font size '%s'", tostring(size))
    end

    local font = { typeface = typeface, size = size }
    local failedName = loadBuiltinEntries(font)
    if not failedName then
        appliedFont = font
        return true, nil
    end

    local message = string.format("Failed to load font '%s' for built-in font '%s'", describeFont(font), failedName)
    local previousFont = appliedFont or NATIVE_BASELINE
    local restoreFailedName = loadBuiltinEntries(previousFont)
    if restoreFailedName then
        appliedFont = nil
        return false, string.format("%s; restoring font '%s' also failed at '%s'",
            message, describeFont(previousFont), restoreFailedName)
    end

    appliedFont = previousFont
    return false, string.format("%s; restored font '%s'", message, describeFont(previousFont))
end
