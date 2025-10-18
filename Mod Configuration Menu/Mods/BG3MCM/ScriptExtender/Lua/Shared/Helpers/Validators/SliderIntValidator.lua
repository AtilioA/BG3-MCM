---@class SliderIntValidator: Validator
SliderIntValidator = _Class:Create("SliderIntValidator", Validator)

--- Better validation could truncate the value to an integer
function SliderIntValidator.Validate(config, value)
    local isValueNumber = type(value) == "number"
    if not isValueNumber then
        return false
    end

    local isValueInteger = math.floor(value) == value
    if not isValueInteger then
        return false
    end

    local isValueWithinRange = value >= config.Options.Min and value <= config.Options.Max
    return isValueWithinRange
end
