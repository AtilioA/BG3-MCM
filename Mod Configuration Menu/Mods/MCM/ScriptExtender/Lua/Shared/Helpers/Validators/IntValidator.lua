---@class IntValidator: Validator
IntValidator = _Class:Create("IntValidator", Validator)

---@param value number
---@return boolean
function IntValidator.Validate(settings, value)
    local isValueNumber = type(value) == "number"
    local isValueInteger = math.floor(value) == value
    return isValueNumber and isValueInteger
end
