---@class KeybindingV2Validator: Validator
KeybindingV2Validator = _Class:Create("KeybindingV2Validator", Validator)

---@param config any
---@param value table
---@return boolean
function KeybindingV2Validator.Validate(config, value)
    -- Ensure the value is a table
    if type(value) ~= "table" then
        return false
    end

    -- At least one of Keyboard or Controller must be present.
    if not value.Keyboard and not value.Controller then
        return false
    end

    -- Validate Keyboard configuration if provided
    if value.Keyboard then
        if type(value.Keyboard) ~= "table" then
            return false
        end

        -- Validate the Keys array: must be a non-empty table of valid scan codes.
        local keys = value.Keyboard.Keys
        if type(keys) ~= "table" or #keys == 0 then
            return false
        end
        for _, key in ipairs(keys) do
            if type(key) ~= "string" or not table.contains(SDLKeys.ScanCodes, key) then
                return false
            end
        end

        -- Validate ModifierKeys if provided: each must be valid.
        local modifierKeys = value.Keyboard.ModifierKeys
        if modifierKeys then
            if type(modifierKeys) ~= "table" then
                return false
            end
            for _, mod in ipairs(modifierKeys) do
                if type(mod) ~= "string" or not table.contains(SDLKeys.Modifiers, mod) then
                    return false
                end
            end
        end
    end

    -- Validate Controller configuration if provided
    if value.Controller then
        if type(value.Controller) ~= "table" then
            return false
        end

        local buttons = value.Controller.Buttons
        if type(buttons) ~= "table" or #buttons == 0 then
            return false
        end
        for _, btn in ipairs(buttons) do
            if type(btn) ~= "string" then
                return false
            end
            -- TODO: Validate btn against list of valid controller buttons
            if not table.contains(Ext.Enums.SDLControllerButton, btn) then
                return false
            end
        end
    end

    return true
end
