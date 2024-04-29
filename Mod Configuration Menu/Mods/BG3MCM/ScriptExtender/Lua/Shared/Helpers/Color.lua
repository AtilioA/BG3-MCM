Color = {}

--- Create a table for the RGBA values from a hex color
---@param hex_color string The hex color to convert to RGBA
---@return table<number>
function Color.hex_to_rgba(hex_color)
    -- Remove the hash from the hex color if it is present
    hex_color = hex_color:gsub("#", "")

    -- Convert the hex color to decimal
    local r = tonumber(hex_color:sub(1, 2), 16) / 255
    local g = tonumber(hex_color:sub(3, 4), 16) / 255
    local b = tonumber(hex_color:sub(5, 6), 16) / 255
    local a = 1.0

    -- Return the RGBA values as a table
    return { r, g, b, a }
end

--- Create a table for the RGBA values
--- This is useful because of syntax highlighting that is not present when typing a table directly
---@param r number
---@param g number
---@param b number
---@param a number
---@return table<number>
function Color.rgba(r, g, b, a)
    return { r, g, b, a }
end

--- Create a table for the RGBA values, normalized to 0-1
--- This is useful because of syntax highlighting that is not present when typing a table directly
---@param r number
---@param g number
---@param b number
---@param a number
---@return table<number>
function Color.normalized_rgba(r, g, b, a)
    return { r / 255, g / 255, b / 255, a }
end
