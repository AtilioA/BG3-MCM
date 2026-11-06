---@class PathValidator
---@field private WINDOWS_INVALID_CHARS string[]
---@field private WINDOWS_INVALID_NAMES string[]
PathValidator = _Class:Create("PathValidator", nil, {
    -- Windows invalid characters: < > : " / \ | ? *
    WINDOWS_INVALID_CHARS = { "<", ">", ":", '"', "/", "\\", "|", "?", "*" },
    -- Windows reserved names
    WINDOWS_INVALID_NAMES = {
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
    },
})

--- Check if a string is a valid path component under Windows rules
---@param str string The string to validate
---@return boolean isValid True if the string is a valid path component
---@return string? errorMessage Error message if invalid, nil if valid
function PathValidator:IsValidPathComponent(str)
    if not str or str == "" then
        return false, "Path component cannot be empty"
    end

    -- Check for leading/trailing whitespace
    if str:match("^%s") or str:match("%s$") then
        return false, "Path component cannot start or end with whitespace"
    end

    -- Check for empty or dot components
    if str == "." or str == ".." then
        return false, "Path component cannot be '.' or '..'"
    end

    -- Check for invalid characters
    for _, char in ipairs(self.WINDOWS_INVALID_CHARS) do
        -- Each entry is a single literal character, also in Lua pattern syntax.
        if str:find(char) then
            return false, string.format("Path contains invalid character: %s", char)
        end
    end

    -- SE Ext.IO rejects control bytes, and its signed-char check also rejects non-ASCII bytes
    if str:find("[^\32-\126]") then
        return false, "Path can only contain ASCII letters, digits, and symbols"
    end

    -- Check for reserved names (case-insensitive)
    local upperStr = str:upper()
    for _, name in ipairs(self.WINDOWS_INVALID_NAMES) do
        if upperStr == name or upperStr:match("^" .. name .. "%..+$") then
            return false, string.format("Path cannot be a reserved name: %s", name)
        end
    end

    -- Check for trailing period (Windows doesn't allow this)
    if str:match("%.$") then
        return false, "Path cannot end with a period"
    end

    -- Check maximum length (255 bytes is a common limit for filenames)
    if #str > 255 then
        return false, "Path component is too long (max 255 characters)"
    end

    return true
end

return PathValidator
