---@class Keybinding
---@field public ScanCode string
---@field public Modifier string

KeybindingManager = {}

KeybindingManager.MOUSE_BUTTON_MIN = 1
KeybindingManager.MOUSE_BUTTON_MAX = 10
KeybindingManager.MOUSE_BUTTON_UNASSIGNED = 0

-- These are the supported modifier values; NONE represents an empty/unmodified binding.
KeybindingManager.SUPPORTED_MODIFIERS = {
    "NONE",
    "LShift",
    "RShift",
    "LCtrl",
    "RCtrl",
    "LAlt",
    "RAlt"
}

local allowedActiveModifiers = {}
for _, modifier in ipairs(KeybindingManager.SUPPORTED_MODIFIERS) do
    if modifier ~= "NONE" then
        allowedActiveModifiers[modifier:upper()] = true
    end
end

-- Checks if a table is a keybinding table
function KeybindingManager:IsKeybindingTable(value)
    return type(value) == "table" and value.ScanCode ~= nil and value.Modifier ~= nil
end

-- Returns true if the given key is an allowed modifier.
function KeybindingManager:IsActiveModifier(key)
    if type(key) ~= "string" then
        return false
    end

    local normalizedKey = key:upper()
    local isActive = allowedActiveModifiers[normalizedKey] or false
    return isActive
end

---@param modifier any
---@return boolean
function KeybindingManager:IsValidModifierKey(modifier)
    if type(modifier) ~= "string" then
        return false
    end

    local normalizedModifier = modifier:upper()
    return normalizedModifier == "NONE" or self:IsActiveModifier(normalizedModifier)
end

---@param modifier any
---@return boolean
function KeybindingManager:IsModifierNull(modifier)
    if modifier == nil then return true end
    if type(modifier) ~= "string" then return false end
    local normalized = modifier:upper()
    return normalized == "" or normalized == "NONE"
end

---Normalizes a modifier list for persistence and exact comparisons.
---Empty strings and legacy NONE sentinels become the canonical empty list.
---@param modifiers string[]|nil
---@return string[]
function KeybindingManager:NormalizeModifiers(modifiers)
    local normalized = {}
    local seen = {}
    for _, modifier in ipairs(modifiers or {}) do
        local value = tostring(modifier):upper()
        if not self:IsModifierNull(value) and not seen[value] then
            seen[value] = true
            table.insert(normalized, value)
        end
    end
    table.sort(normalized)
    return normalized
end

---Adapts author and legacy modifier input to the canonical internal list.
---@param modifiers any
---@return string[]|nil canonicalModifiers
---@return any? invalidModifier
function KeybindingManager:AdaptModifierKeys(modifiers)
    if modifiers == nil then return {} end
    if type(modifiers) ~= "table" then return nil, modifiers end

    for _, modifier in ipairs(modifiers) do
        if not self:IsModifierNull(modifier) and not self:IsValidModifierKey(modifier) then
            return nil, modifier
        end
    end

    return self:NormalizeModifiers(modifiers)
end

---Returns whether a keyboard binding has an assigned primary key.
---@param binding KeybindingKeyboardBinding|nil
---@return boolean
function KeybindingManager:IsKeyboardBindingAssigned(binding)
    return type(binding) == "table" and binding.Key ~= nil and tostring(binding.Key) ~= ""
end

---Returns whether a mouse binding has an assigned button.
---@param binding KeybindingMouseBinding|nil
---@return boolean
function KeybindingManager:IsMouseBindingAssigned(binding)
    return type(binding) == "table" and type(binding.Button) == "number"
        and binding.Button == math.floor(binding.Button)
        and binding.Button >= self.MOUSE_BUTTON_MIN and binding.Button <= self.MOUSE_BUTTON_MAX
end

---Returns the one assigned keyboard or mouse binding from a value or binding table.
---@param value KeybindingV2Value|KeybindingKeyboardBinding|KeybindingMouseBinding|nil
---@return KeybindingKeyboardBinding|KeybindingMouseBinding|nil
function KeybindingManager:GetActiveV2Binding(value)
    if type(value) ~= "table" then return nil end
    if self:IsMouseBindingAssigned(value.Mouse) then return value.Mouse end
    if self:IsKeyboardBindingAssigned(value.Keyboard) then return value.Keyboard end
    if self:IsMouseBindingAssigned(value) then return value end
    if self:IsKeyboardBindingAssigned(value) then return value end
    return nil
end

---Canonicalizes a complete keybinding value to one device and complete flags.
---@param value KeybindingV2Value|nil
---@param fallback? KeybindingV2Value
---@return KeybindingV2Value
function KeybindingManager:CanonicalizeV2Value(value, fallback)
    value = value or {}
    fallback = fallback or {}
    local enabled = value.Enabled
    if enabled == nil then enabled = fallback.Enabled end
    if enabled == nil then enabled = true end
    local allowConflict = value.AllowConflict
    if allowConflict == nil then allowConflict = fallback.AllowConflict end
    if allowConflict == nil then allowConflict = false end

    local canonical = { Enabled = enabled, AllowConflict = allowConflict }
    local active = self:GetActiveV2Binding(value)
    if self:IsMouseBindingAssigned(active) then
        canonical.Mouse = {
            Button = active.Button,
            ModifierKeys = self:NormalizeModifiers(active.ModifierKeys)
        }
    elseif self:IsKeyboardBindingAssigned(active) then
        canonical.Keyboard = {
            Key = tostring(active.Key):upper(),
            ModifierKeys = self:NormalizeModifiers(active.ModifierKeys)
        }
    else
        canonical.Keyboard = { Key = "", ModifierKeys = {} }
    end
    return canonical
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
    for _, mod in ipairs(modifiers or {}) do
        if type(mod) == "string" then
            local normalizedModifier = mod:upper()
            if self:IsActiveModifier(normalizedModifier) then
                activeModifiers[normalizedModifier] = true
            end
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
        if type(mod) ~= "string" then
            return false
        end

        local m = mod:upper()
        if not self:IsModifierNull(m) then
            if not self:IsActiveModifier(m) then return false end
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
