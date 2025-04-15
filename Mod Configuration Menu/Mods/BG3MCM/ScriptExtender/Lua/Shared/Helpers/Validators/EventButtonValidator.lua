---@class EventButtonValidator
EventButtonValidator = {}

--- Validates value for event_button settings
--- Event buttons don't actually have a value to validate, as they don't store state
--- They always pass validation if the value is nil or a valid table structure 
--- (for future extensibility)
---@param setting BlueprintSetting The setting to validate
---@param value any The value to validate
---@return boolean True if the value is valid, false otherwise
function EventButtonValidator.Validate(setting, value)
    -- Event buttons don't store state so their value should typically be nil
    -- Accept nil as the default value
    if value == nil then
        return true
    end
    
    -- For future extensibility, accept a table structure with potential properties
    if type(value) == "table" then
        return true
    end
    
    return false
end

return EventButtonValidator
