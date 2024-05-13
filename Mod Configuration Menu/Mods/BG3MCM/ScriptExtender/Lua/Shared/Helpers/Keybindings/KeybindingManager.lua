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

    if self:IsModifierNull(modifier) then
        return table.isEmpty(e.Modifiers)
    else
        return table.contains(e.Modifiers, modifier)
    end
end

function KeybindingManager:HandleKeyInput(e)
    local toggleKeybinding = KeybindingManager:GetToggleKeybinding()
    if KeybindingManager:IsKeybindingPressed(e, toggleKeybinding) then
        IMGUILayer:ToggleMCMWindow()
    end
end

return KeybindingManager
