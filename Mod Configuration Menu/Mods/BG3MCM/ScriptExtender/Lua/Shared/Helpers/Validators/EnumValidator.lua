---@class EnumValidator: Validator
EnumValidator = _Class:Create("EnumValidator", Validator)

function EnumValidator.Validate(config, value)
    local isValueInOptions = table.contains(config.Options.Choices, value)
    return isValueInOptions
end
