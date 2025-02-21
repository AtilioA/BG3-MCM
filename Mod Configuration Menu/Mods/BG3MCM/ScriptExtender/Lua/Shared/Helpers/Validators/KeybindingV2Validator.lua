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

    -- At least one of Keyboard or Controller must be present.
    if not value.Key and not value.Controller then
        MCMWarn(0, "Validation failed: neither Keyboard nor Controller is present.")
        return false
    end

    -- Validate Keyboard configuration if provided
    if value.Key then
        if type(value.Key) ~= "table" then
            MCMWarn(0, "Validation failed: Keyboard configuration is not a table.")
            return false
        end

        local keys = value.Key
        for _, key in ipairs(keys) do
            if type(key) ~= "string" or not table.contains(SDLKeys.ScanCodes, key) then
                MCMWarn(0, "Validation failed: Invalid key '" .. tostring(key) .. "' in Keys table.")
                return false
            end
        end

        -- Validate ModifierKeys if provided: each must be valid.
        local modifierKeys = value.Key.ModifierKeys
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

    -- Validate Controller configuration if provided
    if value.Controller then
        if type(value.Controller) ~= "table" then
            MCMWarn(0, "Validation failed: Controller configuration is not a table.")
            return false
        end

        local buttons = value.Controller.Buttons
        if type(buttons) ~= "table" then
            MCMWarn(0, "Validation failed: Buttons table is invalid.")
            return false
        end
        for _, btn in ipairs(buttons) do
            if type(btn) ~= "string" then
                MCMWarn(0, "Validation failed: Button '" .. tostring(btn) .. "' is not a string.")
                return false
            end
            -- TODO: Validate btn against list of valid controller buttons
            if not table.contains(Ext.Enums.SDLControllerButton, btn) then
                MCMWarn(0, "Validation failed: Invalid controller button '" .. tostring(btn) .. "'.")
                return false
            end
        end
    end

    MCMDebug(1, "Validation succeeded for keybinding configuration.")
    return true
end
