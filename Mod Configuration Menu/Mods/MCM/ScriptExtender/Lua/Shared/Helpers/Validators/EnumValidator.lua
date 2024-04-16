---@class EnumValidator: Validator
EnumValidator = _Class:Create("EnumValidator", Validator)

function EnumValidator.Validate(settings, value)
    local isValueInOptions = table.contains(settings.Options.Choices, value)
    return isValueInOptions
end
