---@class Keybinding
---@field public ScanCode string
---@field public Modifier string

KeybindingManager = {}

function KeybindingManager:IsKeybindingTable(value)
    return type(value) == "table" and value.ScanCode ~= nil and value.Modifier ~= nil
end

function KeybindingManager:IsActiveModifier(modifier)
    return table.contains({
        "LShift",
        "RShift",
        "LCtrl",
        "RCtrl",
        "LAlt",
        "RAlt"
    }, modifier)
end

function KeybindingManager:GetToggleKeybinding()
    local toggleKeybinding = MCMClientState:GetClientStateValue(ModuleUUID, "toggle_mcm_keybinding")
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

function KeybindingManager:ExtractActiveModifiers(modifiers)
    local activeModifiers = {}
    for _, mod in ipairs(modifiers) do
        if self:IsActiveModifier(mod) then
            activeModifiers[mod] = true
        end
    end
    return activeModifiers
end

function KeybindingManager:AreAllModifiersPresent(eModifiers, activeModifiers)
    for _, mod in ipairs(eModifiers) do
        if self:IsActiveModifier(mod) and not activeModifiers[mod] then
            return false
        end
    end
    return true
end

function KeybindingManager:AreAllActiveModifiersPressed(eActiveModifiers, activeModifiers)
    for mod, _ in pairs(activeModifiers) do
        if not eActiveModifiers[mod] then
            return false
        end
    end
    return true
end

function KeybindingManager:IsModifierPressed(e, modifiers)
    local modifiersTable = type(modifiers) == "table" and modifiers or { modifiers }
    -- Necessary to ignore modifiers such as scroll lock, num lock, etc.
    local activeModifiers = self:ExtractActiveModifiers(modifiersTable)
    local eActiveModifiers = self:ExtractActiveModifiers(e.Modifiers)

    return self:AreAllModifiersPresent(e.Modifiers, activeModifiers) and
    self:AreAllActiveModifiersPressed(eActiveModifiers, activeModifiers)
end

return KeybindingManager
