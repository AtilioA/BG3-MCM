---@class DragFloatValidator: Validator
DragFloatValidator = _Class:Create("DragFloatValidator", Validator)

function DragFloatValidator.Validate(config, value)
    local isValueNumber = type(value) == "number"
    if not isValueNumber then
        return false
    end
    
    local isValueWithinRange = value >= config.Options.Min and value <= config.Options.Max
    return isValueWithinRange
end
