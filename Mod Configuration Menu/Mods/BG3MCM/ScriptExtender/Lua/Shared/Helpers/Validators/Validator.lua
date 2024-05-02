---@class Validator
Validator = _Class:Create("Validator", nil, {})

function Validator:New()
    error(
        "This is an abstract class and cannot be instantiated directly. Validator:New() must be overridden in a derived class")
end

--- Validate the given value against the config.
--- This is a static method, so it can be called without an instance of the class.
--- Validators will have individual implementations that dictate whether a certain value is valid or not for a given type of setting.
---@param value any The value to validate
---@return boolean valid if the value is valid, false otherwise
function Validator.Validate(config, value)
    error("Validator:Validate(value) must be overridden in a derived class")
end
