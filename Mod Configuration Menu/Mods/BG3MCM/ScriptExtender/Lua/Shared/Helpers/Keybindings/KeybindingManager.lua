---@class Keybinding
---@field public ScanCode string
---@field public Modifier string

KeybindingManager = {}

function KeybindingManager:IsKeybindingTable(value)
    return type(value) == "table" and value.ScanCode ~= nil and value.Modifier ~= nil
end

function KeybindingManager:IsActiveModifier(key)
    local activeModifiers = {
        ["LShift"] = true,
        ["RShift"] = true,
        ["LCtrl"] = true,
        ["RCtrl"] = true,
        ["LAlt"] = true,
        -- TODO: don't have time to fix the case sensitivity issue right now
        ["RAlt"] = true,
        ["LSHIFT"] = true,
        ["RSHIFT"] = true,
        ["LCTRL"] = true,
        ["RCTRL"] = true,
        ["LALT"] = true,
        ["RALT"] = true
    }

    return activeModifiers[key:upper()] or activeModifiers[key] or false
end

function KeybindingManager:GetToggleKeybinding()
    local toggleKeybinding = MCMClientState:GetClientStateValue("toggle_mcm_keybinding", ModuleUUID)
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

-- TODO: fix this
function KeybindingManager:IsKeybindingPressed(e, keybinding)
    local scanCode = keybinding.ScanCode
    local modifier = keybinding.Modifier

    _D("Key event:")
    _D(e)
    if type(scanCode) == "table" then
        _D(scanCode)
        scanCode = scanCode[1]
    end
    --     for _, key in ipairs(scanCode) do
    --         if self:IsKeybindingPressed(e, { ScanCode = key, Modifier = modifier }) then
    --             return true
    --         end
    --     end
    --     return false
    -- else
    _D("Does event key match keybinding?")
    _D(scanCode)
    _D(e.Key)
    if e.Key ~= scanCode then
        _D("KeybindingManager:IsKeybindingPressed: false")
        _D("Event keys:")
        _D(e.Key)
        _D(e.Modifiers)

        _D("keybinding keys:")
        _D(scanCode)
        _D(modifier)
        return false
    end


    _D("Matching key was pressed. Checking modifiers")

    return self:IsModifierPressed(e, modifier)
    -- end
end

function KeybindingManager:HandleKeyUpInput(e)
    local toggleKeybinding = KeybindingManager:GetToggleKeybinding()
    if KeybindingManager:IsKeybindingPressed(e, toggleKeybinding) then
        IMGUILayer:ToggleMCMWindow(true)
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
        if self:IsActiveModifier(mod:upper()) and not activeModifiers[mod:upper()] then
            _P(mod .. " is active but not present in activeModifiers")
            return false
        end
    end
    return true
end

function KeybindingManager:AreAllActiveModifiersPressed(eActiveModifiers, activeModifiers)
    for mod, _ in pairs(activeModifiers) do
        if not eActiveModifiers[mod] then
            _P(mod .. " is present in activeModifiers but not active")
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

    _D(activeModifiers)
    _D(eActiveModifiers)

    return self:AreAllModifiersPresent(e.Modifiers, activeModifiers) and
        self:AreAllActiveModifiersPressed(eActiveModifiers, activeModifiers)
end

return KeybindingManager
