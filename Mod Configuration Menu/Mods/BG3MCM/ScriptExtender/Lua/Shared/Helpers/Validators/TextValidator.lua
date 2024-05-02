---@class TextValidator: Validator
TextValidator = _Class:Create("TextValidator", Validator)

function TextValidator.Validate(config, value)
    return type(value) == "string"
end
