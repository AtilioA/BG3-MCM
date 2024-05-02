---@class RadioValidator: Validator
RadioValidator = _Class:Create("RadioValidator", Validator)

function RadioValidator.Validate(config, value)
    local availableOptions = config.Options.Choices
    local isOptionValid = table.contains(availableOptions, value)
    return isOptionValid
end
