---@class DictValidator: Validator
DictValidator = _Class:Create("DictValidator", Validator)

function DictValidator.Validate(settings, value)
    return type(value) == "table"
end
