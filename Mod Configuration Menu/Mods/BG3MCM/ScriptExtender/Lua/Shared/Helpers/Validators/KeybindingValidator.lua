---@class KeybindingValidator: Validator
KeybindingValidator = _Class:Create("KeybindingValidator", Validator)

---@param value Keybinding
---@return boolean
function KeybindingValidator.Validate(config, value)
    local isScanCodeString = type(value.ScanCode) == "string"
    if not isScanCodeString then
        return false
    end

    local validScanCode = table.contains(SDLKeys.ScanCodes, value.ScanCode)
    local validModifier = value.Modifier == nil or value.Modifier == "" or
    table.contains(SDLKeys.Modifiers, value.Modifier)

    return validScanCode and validModifier
end
