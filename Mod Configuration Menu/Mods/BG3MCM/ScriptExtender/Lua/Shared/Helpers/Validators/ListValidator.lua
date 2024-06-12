---@class ListValidator: Validator
ListValidator = _Class:Create("ListValidator", Validator)

function ListValidator.Validate(config, value)
    -- return type(value) == "string"
    -- TODO: perform actual validation
    return true
end
