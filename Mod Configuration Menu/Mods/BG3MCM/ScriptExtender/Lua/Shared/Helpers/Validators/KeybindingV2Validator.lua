---@class KeybindingV2Validator: Validator
KeybindingV2Validator = _Class:Create("KeybindingV2Validator", Validator)

---@param config any
---@param value table
---@return boolean
function KeybindingV2Validator.Validate(config, value)
    if type(value) ~= "table" then
        MCMWarn(0, "Validation failed: value is not a table.")
        return false
    end

    local hasKeyboard = value.Keyboard and type(value.Keyboard) == "table"
    local hasMouse = value.Mouse and type(value.Mouse) == "table"

    if not hasKeyboard and not hasMouse then
        MCMWarn(0, "Validation failed: Either Keyboard or Mouse binding must be present.")
        return false
    end

    if hasKeyboard and hasMouse then
        local kbHasValue = value.Keyboard.Key and value.Keyboard.Key ~= ""
        local mouseHasValue = value.Mouse.Button and value.Mouse.Button > 0
        if kbHasValue and mouseHasValue then
            MCMWarn(0, "Validation failed: Cannot have both Keyboard and Mouse bindings assigned. Use one or the other.")
            return false
        end
    end

    if hasKeyboard then
        local keyboard = value.Keyboard
        if keyboard.Key then
            if type(keyboard.Key) ~= "string" then
                MCMWarn(0, "Validation failed: Keyboard.Key is not a string.")
                return false
            end
            if keyboard.Key ~= "" and not table.contains(SDLKeys.ScanCodes, keyboard.Key) then
                MCMWarn(0, "Validation failed: Invalid key '" .. tostring(keyboard.Key) .. "'.")
                return false
            end
        end

        if keyboard.ModifierKeys then
            if type(keyboard.ModifierKeys) ~= "table" then
                MCMWarn(0, "Validation failed: Keyboard.ModifierKeys is not a table.")
                return false
            end
            for _, mod in ipairs(keyboard.ModifierKeys) do
                if type(mod) ~= "string" or not table.contains(SDLKeys.Modifiers, mod) then
                    MCMWarn(0, "Validation failed: Invalid modifier key '" .. tostring(mod) .. "'.")
                    return false
                end
            end
        end
    end

    if hasMouse then
        local mouse = value.Mouse
        if mouse.Button ~= nil then
            if type(mouse.Button) ~= "number" then
                MCMWarn(0, "Validation failed: Mouse.Button is not a number.")
                return false
            end
            if mouse.Button < 0 or mouse.Button > 10 then
                MCMWarn(0, "Validation failed: Mouse.Button must be between 0 and 10, got '" .. tostring(mouse.Button) .. "'.")
                return false
            end
        end

        if mouse.ModifierKeys then
            if type(mouse.ModifierKeys) ~= "table" then
                MCMWarn(0, "Validation failed: Mouse.ModifierKeys is not a table.")
                return false
            end
            for _, mod in ipairs(mouse.ModifierKeys) do
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
