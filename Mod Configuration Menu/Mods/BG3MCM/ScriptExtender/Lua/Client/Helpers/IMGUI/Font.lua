Font = {}

-- Key-value map of logical size -> numeric value (px)
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

-- Font definitions: typeface -> file path
local FONT_DEFINITIONS = {
    ["Inter-Regular"] = "Mods/BG3MCM/Assets/Fonts/Inter/Inter-Regular.ttf",
    ["OpenDyslexic"] = "Mods/BG3MCM/Assets/Fonts/OpenDyslexic/OpenDyslexic.ttf",
}

-- Track which fonts have been loaded
-- Might not be strictly necessary, but avoids re
-- Key format: "TypefaceSizeKey" (e.g., "Inter-RegularDefault")
local loadedFonts = {}

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
    if fontSize == nil then
        return false
    end

    local key = _normalizeSizeKey(fontSize)
    if key == nil then return false end
    return Font.FONT_SIZE_OPTIONS[key] ~= nil
end

function Font.GetSizeValue(fontSize)
    local key = _normalizeSizeKey(fontSize)
    if key and Font.FONT_SIZE_OPTIONS[key] then
        return Font.FONT_SIZE_OPTIONS[key]
    end

    if type(fontSize) == "number" then
        return fontSize
    end
    return nil
end

-- Compose a font resource name by appending the size key
function Font.GetFontNameWithSizeSuffix(typeface, fontSize)
    if typeface == nil then return nil end
    local size = _normalizeSizeKey(fontSize)
    if size == nil then
        return tostring(typeface)
    end
    return string.format("%s%s", tostring(typeface), VCString.ToTitleCase(size))
end

--- Lazily load a font if it hasn't been loaded yet
--- Only used for loading custom fonts (default font is always available)
--- @param typeface string The typeface name (e.g., "Inter-Regular", "OpenDyslexic")
--- @param fontSize string The font size key (e.g., "Default", "Large")
--- @return boolean True if font was loaded or already loaded, false if font doesn't exist
function Font.EnsureFontLoaded(typeface, fontSize)
    -- Empty/nil typeface means use default IMGUI font (no loading needed)
    if not typeface or typeface == "" then
        return true
    end

    -- Normalize the size key
    local sizeKey = _normalizeSizeKey(fontSize)
    if not sizeKey or not Font.FONT_SIZE_OPTIONS[sizeKey] then
        MCMWarn(0, "Invalid font size: " .. tostring(fontSize))
        return false
    end

    -- Check if this font definition exists
    local fontPath = FONT_DEFINITIONS[typeface]
    if not fontPath then
        MCMWarn(0, "Unknown font typeface: " .. tostring(typeface))
        return false
    end

    -- Create tracking key
    local fullFontName = Font.GetFontNameWithSizeSuffix(typeface, sizeKey)
    if not fullFontName then
        MCMWarn(0, "Failed to generate font name for: " .. tostring(typeface) .. " " .. tostring(sizeKey))
        return false
    end

    -- Check if already loaded
    if loadedFonts[fullFontName] then
        return true
    end

    -- Load the font
    local sizeValue = Font.FONT_SIZE_OPTIONS[sizeKey]
    MCMDebug(2, "Loading font: " .. fullFontName .. " from " .. fontPath .. " at size " .. tostring(sizeValue))
    local successLoad = Ext.IMGUI.LoadFont(fullFontName, fontPath, sizeValue)

    if not successLoad then
        MCMWarn(0, "Failed to load font: " .. fullFontName .. " from " .. fontPath .. " at size " .. tostring(sizeValue))
        return false
    end

    -- Mark as loaded
    loadedFonts[fullFontName] = true

    return true
end
