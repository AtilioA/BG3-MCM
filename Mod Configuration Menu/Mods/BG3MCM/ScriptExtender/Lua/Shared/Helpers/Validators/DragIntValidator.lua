---@class DragIntValidator: Validator
DragIntValidator = _Class:Create("DragIntValidator", Validator)

function DragIntValidator.Validate(config, value)
    local isValueNumber = type(value) == "number"
    local isValueWithinRange = value >= config.Options.Min and value <= config.Options.Max
    return isValueNumber and isValueWithinRange
end
