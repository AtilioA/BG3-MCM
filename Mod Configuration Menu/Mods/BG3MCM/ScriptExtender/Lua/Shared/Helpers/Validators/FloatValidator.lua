---@class FloatValidator: Validator
FloatValidator = _Class:Create("FloatValidator", Validator)

function FloatValidator.Validate(config, value)
    if type(value) ~= "number" then
        return false
    end
    local options = config:GetOptions()
    if type(options) == "table" then
        if type(options.Min) == "number" and not FloatUtils.isWithinEpsilon(value, options.Min, nil) then
            return false
        end
        if type(options.Max) == "number" and not FloatUtils.isWithinEpsilon(value, nil, options.Max) then
            return false
        end
    end
    return true
end
