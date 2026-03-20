---@class EnumValidator: Validator
EnumValidator = _Class:Create("EnumValidator", Validator)

function EnumValidator.Validate(config, value)
    return EnumChoicesHelper.IsValueValid(config, value)
end
