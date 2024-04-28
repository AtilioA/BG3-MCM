---@class DragFloatValidator: Validator
DragFloatValidator = _Class:Create("DragFloatValidator", Validator)

function DragFloatValidator.Validate(settings, value)
    local isValueNumber = type(value) == "number"
    local isValueWithinRange = value >= settings.Options.Min and value <= settings.Options.Max
    return isValueNumber and isValueWithinRange
end
