---@class RadioValidator: Validator
RadioValidator = _Class:Create("RadioValidator", Validator)

function RadioValidator.Validate(settings, value)
    local availableOptions = settings.Options.Choices
    local isOptionValid = table.contains(availableOptions, value)
    return isOptionValid
end
