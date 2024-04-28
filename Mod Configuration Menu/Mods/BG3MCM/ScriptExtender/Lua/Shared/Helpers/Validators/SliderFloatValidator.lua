---@class SliderFloatValidator: Validator
SliderFloatValidator = _Class:Create("SliderFloatValidator", Validator)

function SliderFloatValidator.Validate(settings, value)
    local isValueNumber = type(value) == "number"
    local isValueWithinRange = value >= settings.Options.Min and value <= settings.Options.Max
    return isValueNumber and isValueWithinRange
end
