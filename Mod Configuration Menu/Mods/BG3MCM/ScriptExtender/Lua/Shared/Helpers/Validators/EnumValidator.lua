---@class EnumValidator: Validator
EnumValidator = _Class:Create("EnumValidator", Validator)

function EnumValidator.Validate(config, value)
    local hasOptions = config.Options ~= nil and config.Options.Choices ~= nil
    if not hasOptions then
        return false
    end

    local isValueInOptions = table.contains(config.Options.Choices, value)
    return isValueInOptions
end
