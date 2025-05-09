---@class KeybindingV2Validator: Validator
KeybindingV2Validator = _Class:Create("KeybindingV2Validator", Validator)

---@param config any
---@param value table
---@return boolean
function KeybindingV2Validator.Validate(config, value)
    -- Ensure the value is a table
    if type(value) ~= "table" then
        MCMWarn(0, "Validation failed: value is not a table.")
        return false
    end

    if not value.Keyboard then
        MCMWarn(0, "Validation failed: Keyboard key is not present.")
        return false
    end

    -- Validate Keyboard configuration if provided
    if value.Key then
        if type(value.Key) ~= "string" then
            MCMWarn(0, "Validation failed: Keyboard configuration 'Key' is not a string.")
            return false
        end
        if not table.contains(SDLKeys.ScanCodes, value.Key) then
            MCMWarn(0, "Validation failed: Invalid key '" .. tostring(value.Key) .. "'.")
            return false
        end

        -- Validate ModifierKeys if provided: each must be valid.
        local modifierKeys = value.ModifierKeys
        if modifierKeys then
            if type(modifierKeys) ~= "table" then
                MCMWarn(0, "Validation failed: ModifierKeys is not a table.")
                return false
            end
            for _, mod in ipairs(modifierKeys) do
                if type(mod) ~= "string" or not table.contains(SDLKeys.Modifiers, mod) then
                    MCMWarn(0, "Validation failed: Invalid modifier key '" .. tostring(mod) .. "'.")
                    return false
                end
            end
        end
    end

    MCMDebug(2, "Validation succeeded for keybinding configuration.")
    return true
end
