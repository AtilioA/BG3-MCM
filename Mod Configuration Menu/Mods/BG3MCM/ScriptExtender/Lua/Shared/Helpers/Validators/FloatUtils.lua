---@class FloatUtils: Validator
FloatUtils = _Class:Create("FloatUtils", Validator)

-- TODO: make this configurable in a setting-by-setting basis, since some settings may be more sensitive than others
-- This should be a good start for now
FloatUtils.EPSILON = 1e-6

--- Checks if a value is within [min, max] with epsilon tolerance.
--- If min or max is nil, that bound is ignored.
function FloatUtils.isWithinEpsilon(value, min, max, epsilon)
    epsilon = epsilon or FloatUtils.EPSILON
    if min ~= nil and value < min - epsilon then
        return false
    end
    if max ~= nil and value > max + epsilon then
        return false
    end
    return true
end
