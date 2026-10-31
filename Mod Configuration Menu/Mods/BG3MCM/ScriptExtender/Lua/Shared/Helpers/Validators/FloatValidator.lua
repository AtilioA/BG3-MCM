---@class FloatValidator: Validator
FloatValidator = _Class:Create("FloatValidator", Validator)

function FloatValidator.Validate(config, value)
    if type(value) ~= "number" then
        return false
    end
    local options = config:GetOptions()
    if options.Min and not FloatUtils.isWithinEpsilon(value, options.Min, nil) then
        return false
    end
    if options.Max and not FloatUtils.isWithinEpsilon(value, nil, options.Max) then
        return false
    end
    return true
end
