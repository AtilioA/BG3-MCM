---@class PathValidator
---@field private WINDOWS_INVALID_CHARS string[]
---@field private WINDOWS_INVALID_NAMES string[]
---@field private UNIX_INVALID_CHARS string[]
PathValidator = _Class:Create("PathValidator", nil, {
    -- Windows invalid characters: < > : " / \ | ? *
    WINDOWS_INVALID_CHARS = { "<", ">", ":", '"', "/", "\\", "|", "?", "*" },
    -- Windows reserved names
    WINDOWS_INVALID_NAMES = {
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
    },
    -- Unix invalid characters: NUL and /
    UNIX_INVALID_CHARS = { "\0", "/" }
})

--- Check if a string contains any invalid path characters for the given OS
---@param str string The string to validate
---@param isWindows? boolean Whether to check Windows (true) or Unix (false) path rules
---@return boolean isValid True if the string is a valid path component
---@return string? errorMessage Error message if invalid, nil if valid
function PathValidator:IsValidPathComponent(str, isWindows)
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

    local invalidChars = isWindows and self.WINDOWS_INVALID_CHARS or self.UNIX_INVALID_CHARS

    -- Check for invalid characters
    for _, char in ipairs(invalidChars) do
        if str:find(char, 1, true) then -- true for plain search (no patterns)
            return false, string.format("Path contains invalid character: %s", char)
        end
    end

    -- Windows-specific checks
    if isWindows then
        -- Check for reserved names (case-insensitive)
        local upperStr = str:upper()
        for _, name in ipairs(self.WINDOWS_INVALID_NAMES) do
            if upperStr == name or upperStr:match("^" .. name .. "%..+$") then
                return false, string.format("Path cannot be a reserved name: %s", name)
            end
        end

        -- Check for trailing period or space (Windows doesn't allow this)
        if str:match("%.$") or str:match("%s$") then
            return false, "Path cannot end with a period or space"
        end
    end

    -- Check maximum length (255 bytes is a common limit for filenames)
    if #str > 255 then
        return false, "Path component is too long (max 255 characters)"
    end

    return true
end

--- Check if a path is valid for both Windows and Unix systems
---@param path string The path to validate
---@return boolean isValid True if the path is valid for both systems
---@return string? errorMessage Error message if invalid, nil if valid
function PathValidator:IsValidPath(path)
    if not path or path == "" then
        return false, "Path cannot be empty"
    end

    -- Split the path into components
    local components = {}
    for component in path:gmatch("[^/\\]+") do
        table.insert(components, component)
    end

    -- Check each component
    for _, component in ipairs(components) do
        -- Check Windows validity
        local winValid, winError = self:IsValidPathComponent(component, true)
        if not winValid then
            return false, string.format("Invalid path component for Windows: %s (%s)", component, winError)
        end

        -- Check Unix validity (skip the drive letter check for the first component)
        local unixValid, unixError = self:IsValidPathComponent(component, false)
        if not unixValid then
            return false, string.format("Invalid path component for Unix: %s (%s)", component, unixError)
        end
    end

    return true
end

return PathValidator
