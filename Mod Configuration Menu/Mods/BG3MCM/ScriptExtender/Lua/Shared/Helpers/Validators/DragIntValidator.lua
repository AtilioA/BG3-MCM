---@class DragIntValidator: Validator
DragIntValidator = _Class:Create("DragIntValidator", Validator)

function DragIntValidator.Validate(config, value)
    if type(value) ~= "number" or math.floor(value) ~= value then
        return false
    end

    local options = config:GetOptions()
    if type(options) ~= "table" or type(options.Min) ~= "number" or type(options.Max) ~= "number" then
        return false
    end

    return value >= options.Min and value <= options.Max
end
