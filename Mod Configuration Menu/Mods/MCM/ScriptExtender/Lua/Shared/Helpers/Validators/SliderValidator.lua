---@class SliderValidator: Validator
SliderValidator = _Class:Create("SliderValidator", Validator)

function SliderValidator.Validate(settings, value)
    local isValueNumber = type(value) == "number"
    local isValueWithinRange = value >= settings.Options.Min and value <= settings.Options.Max
    return isValueNumber and isValueWithinRange
end
