---@class SliderFloatValidator: Validator
SliderFloatValidator = _Class:Create("SliderFloatValidator", Validator)

function SliderFloatValidator.Validate(config, value)
    local isValueNumber = type(value) == "number"
    local isValueWithinRange = value >= config.Options.Min and value <= config.Options.Max
    return isValueNumber and isValueWithinRange
end
