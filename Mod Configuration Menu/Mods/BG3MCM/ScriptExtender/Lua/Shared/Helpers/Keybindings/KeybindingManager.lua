---@class Keybinding
---@field public ScanCode string
---@field public Modifier string

KeybindingManager = {}

-- Only these modifiers are relevant
local allowedActiveModifiers = {
    LSHIFT = true,
    RSHIFT = true,
    LCTRL  = true,
    RCTRL  = true,
    LALT   = true,
    RALT   = true,
}

-- Checks if a table is a keybinding table
function KeybindingManager:IsKeybindingTable(value)
    return type(value) == "table" and value.ScanCode ~= nil and value.Modifier ~= nil
end

-- Returns true if the given key is an allowed modifier.
function KeybindingManager:IsActiveModifier(key)
    local normalizedKey = key:upper()
    local isActive = allowedActiveModifiers[normalizedKey] or false
    return isActive
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

-- Check if the event matches the keybinding (both key and modifiers)
function KeybindingManager:IsKeybindingPressed(e, keybinding)
    local scanCode = keybinding.ScanCode
    local modifier = keybinding.Modifier

    if type(scanCode) == "table" then
        scanCode = scanCode[1]
    end

    if e.Key ~= scanCode then
        return false
    end

    return self:IsModifierPressed(e, modifier)
end

-- Returns a set (table with keys) of 'active modifiers' from a given modifiers list.
function KeybindingManager:ExtractActiveModifiers(modifiers)
    local activeModifiers = {}
    for _, mod in ipairs(modifiers) do
        local normalizedModifier = mod:upper()
        if self:IsActiveModifier(normalizedModifier) then
            activeModifiers[normalizedModifier] = true
        end
    end
    return activeModifiers
end

-- Checks that all required modifiers are pressed.
-- Both the keybinding modifiers and event modifiers are normalized and filtered to only allowed ones.
function KeybindingManager:IsModifierPressed(e, modifiers)
    local requiredSet = {}
    if type(modifiers) == "table" then
        for _, mod in ipairs(modifiers) do
            local normalizedModifier = mod:upper()
            if self:IsActiveModifier(normalizedModifier) then
                requiredSet[normalizedModifier] = true
            end
        end
    else
        local normalizedModifier = modifiers:upper()
        if self:IsActiveModifier(normalizedModifier) then
            requiredSet[normalizedModifier] = true
        end
    end

    local eventActiveModifierSet = self:ExtractActiveModifiers(e.Modifiers)

    for reqMod, _ in pairs(requiredSet) do
        if not eventActiveModifierSet[reqMod] then
            return false
        end
    end
    for eventMod, _ in pairs(eventActiveModifierSet) do
        if not requiredSet[eventMod] then
            return false
        end
    end

    return true
end

function KeybindingManager:HandleKeyUpInput(e)
    local toggleKeybinding = self:GetToggleKeybinding()
    -- TODO: decouple this MCM logic from the keybinding manager
    if self:IsKeybindingPressed(e, toggleKeybinding) then
        IMGUILayer:ToggleMCMWindow(true)
    end
end

return KeybindingManager
