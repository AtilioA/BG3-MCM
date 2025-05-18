---@class FloatValidator: Validator
FloatValidator = _Class:Create("FloatValidator", Validator)

function FloatValidator.Validate(config, value)
    if type(value) ~= "number" then
        return false
    end
    if config and config.Options then
        if config.Options.Min and not FloatUtils.isWithinEpsilon(value, config.Options.Min, nil) then
            return false
        end
        if config.Options.Max and not FloatUtils.isWithinEpsilon(value, nil, config.Options.Max) then
            return false
        end
    end
    return true
end
