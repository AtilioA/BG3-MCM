---@class ColorValidator: Validator
ColorValidator = _Class:Create("ColorValidator", Validator)

local function validateColorValue(value)
    return type(value) == "number" and value >= 0 and value <= 1
end

local function validateColorTable(value)
    if type(value) ~= "table" or #value ~= 4 then
        return false
    end

    for i = 1, 4 do
        if not validateColorValue(value[i]) then
            return false
        end
    end

    return true
end

function ColorValidator.Validate(config, value)
    local isValidColorTable = validateColorTable(value)

    return isValidColorTable
end
