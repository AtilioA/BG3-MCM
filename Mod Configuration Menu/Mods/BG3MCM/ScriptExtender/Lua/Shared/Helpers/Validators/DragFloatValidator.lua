---@class DragFloatValidator: Validator
DragFloatValidator = _Class:Create("DragFloatValidator", Validator)

function DragFloatValidator.Validate(config, value)
    if type(value) ~= "number" then
        return false
    end
    local min, max = config.Options.Min, config.Options.Max
    return FloatUtils.isWithinEpsilon(value, min, max)
end
