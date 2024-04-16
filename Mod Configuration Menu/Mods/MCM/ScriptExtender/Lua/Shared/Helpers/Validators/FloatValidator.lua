---@class FloatValidator: Validator
FloatValidator = _Class:Create("FloatValidator", Validator)

function FloatValidator.Validate(settings, value)
    return type(value) == "number"
end
