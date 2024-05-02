---@class IntValidator: Validator
IntValidator = _Class:Create("IntValidator", Validator)

---@param value number
---@return boolean
function IntValidator.Validate(config, value)
    local isValueNumber = type(value) == "number"
    if not isValueNumber then
        return false
    end

    local isValueInteger = math.floor(value) == value
    return isValueNumber and isValueInteger
end
