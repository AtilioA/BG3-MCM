---@class CheckboxValidator: Validator
CheckboxValidator = _Class:Create("CheckboxValidator", Validator)

function CheckboxValidator.Validate(config, value)
    return type(value) == "boolean"
end
