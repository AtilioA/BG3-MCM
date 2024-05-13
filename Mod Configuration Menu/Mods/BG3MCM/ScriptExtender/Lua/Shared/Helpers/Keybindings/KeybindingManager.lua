---@class Keybinding
---@field public ScanCode string
---@field public Modifier string

KeybindingManager = {}

function KeybindingManager:IsKeybindingTable(value)
    return type(value) == "table" and value.ScanCode ~= nil and value.Modifier ~= nil
end

function KeybindingManager:GetToggleKeybinding()
    local toggleKeybinding = MCMAPI:GetSettingValue("toggle_mcm_keybinding", ModuleUUID)
    if not toggleKeybinding then
        toggleKeybinding = {
            ScanCode = "INSERT",
            Modifier = "NONE"
        }
    end
    return toggleKeybinding
end

function KeybindingManager:IsModifierNull(modifier)
    return modifier == nil or modifier == "" or modifier == "NONE"
end

function KeybindingManager:IsKeybindingPressed(e, keybinding)
    local scanCode = keybinding.ScanCode
    local modifier = keybinding.Modifier

    if e.Key ~= scanCode then
        return false
    end


    return self:IsModifierPressed(e, modifier)
end

function KeybindingManager:HandleKeyInput(e)
    local toggleKeybinding = KeybindingManager:GetToggleKeybinding()
    if KeybindingManager:IsKeybindingPressed(e, toggleKeybinding) then
        IMGUILayer:ToggleMCMWindow()
    end
end

function KeybindingManager:IsModifierPressed(e, modifier)
    if #e.Modifiers == 0 then
        return self:IsModifierNull(modifier)
    else
        for _, modifierKey in ipairs(e.Modifiers) do
            if modifierKey == modifier then
                return true
            end
        end
    end
    return false
end

return KeybindingManager
