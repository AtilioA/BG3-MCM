---@class FloatValidator: Validator
FloatValidator = _Class:Create("FloatValidator", Validator)

function FloatValidator.Validate(config, value)
    return type(value) == "number"
end
