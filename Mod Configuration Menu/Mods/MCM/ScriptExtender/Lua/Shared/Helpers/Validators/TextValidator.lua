---@class TextValidator: Validator
TextValidator = _Class:Create("TextValidator", Validator)

function TextValidator.Validate(settings, value)
    return type(value) == "string"
end
