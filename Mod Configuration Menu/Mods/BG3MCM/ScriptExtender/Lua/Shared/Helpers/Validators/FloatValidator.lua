---@class FloatValidator: Validator
FloatValidator = _Class:Create("FloatValidator", Validator)

function FloatValidator.Validate(config, value)
    if type(value) ~= "number" then
        return false
    end
    if config and config.GetOptions then
        if config:GetOptions().Min and not FloatUtils.isWithinEpsilon(value, config:GetOptions().Min, nil) then
            return false
        end
        if config:GetOptions().Max and not FloatUtils.isWithinEpsilon(value, nil, config:GetOptions().Max) then
            return false
        end
    end
    return true
end
