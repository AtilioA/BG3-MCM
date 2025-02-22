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
function KeybindingManager:IsModifierPressed(e, modifiers)
    -- Normalize modifiers to a table
    local mods = type(modifiers) == "table" and modifiers or { modifiers }
    local requiredSet = {}
    for _, mod in ipairs(mods) do
        local m = mod:upper()
        if self:IsActiveModifier(m) then
            requiredSet[m] = true
        end
    end

    local eventSet = self:ExtractActiveModifiers(e.Modifiers)

    -- Check that both sets are exactly equal:
    for mod in pairs(requiredSet) do
        if not eventSet[mod] then
            return false
        end
    end
    for mod in pairs(eventSet) do
        if not requiredSet[mod] then
            return false
        end
    end

    return true
end

return KeybindingManager
