---@class CheckboxValidator: Validator
CheckboxValidator = _Class:Create("CheckboxValidator", Validator)

function CheckboxValidator.Validate(settings, value)
    return type(value) == "boolean"
end
