---@class DragIntValidator: Validator
DragIntValidator = _Class:Create("DragIntValidator", Validator)

function DragIntValidator.Validate(settings, value)
    local isValueNumber = type(value) == "number"
    local isValueWithinRange = value >= settings.Options.Min and value <= settings.Options.Max
    return isValueNumber and isValueWithinRange
end
