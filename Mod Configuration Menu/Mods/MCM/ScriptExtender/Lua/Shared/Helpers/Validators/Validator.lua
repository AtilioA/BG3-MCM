---@class Validator
Validator = _Class:Create("Validator", nil, {})

function Validator:New()
    error(
        "This is an abstract class and cannot be instantiated directly. Validator:New() must be overridden in a derived class")
end

--- Validate the given value against the settings.
--- This is a static method, so it can be called without an instance of the class.
---@param value any The value to validate
---@return boolean valid if the value is valid, false otherwise
function Validator.Validate(settings, value)
    error("Validator:Validate(value) must be overridden in a derived class")
end
