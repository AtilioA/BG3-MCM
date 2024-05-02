---@class DragFloatValidator: Validator
DragFloatValidator = _Class:Create("DragFloatValidator", Validator)

function DragFloatValidator.Validate(config, value)
    local isValueNumber = type(value) == "number"
    local isValueWithinRange = value >= config.Options.Min and value <= config.Options.Max
    return isValueNumber and isValueWithinRange
end
