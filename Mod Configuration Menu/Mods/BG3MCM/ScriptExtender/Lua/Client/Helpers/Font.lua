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
