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

---Returns one device-aware identity for an assigned keyboard or mouse binding.
---@param value KeybindingV2Value|KeybindingKeyboardBinding|KeybindingMouseBinding|nil
---@return string|nil
function KeybindingManager:GetBindingIdentity(value)
    local active = self:GetActiveV2Binding(value)
    if not active then return nil end

    local modifiers = table.concat(self:NormalizeModifiers(active.ModifierKeys), "+")
    if self:IsMouseBindingAssigned(active) then
        return "mouse:" .. tostring(active.Button) .. ":" .. modifiers
    end

    return "keyboard:" .. tostring(active.Key):upper() .. ":" .. modifiers
end

---Compares complete values or bindings by assigned device, primary input, and modifier identity.
---@param value1 KeybindingV2Value|KeybindingKeyboardBinding|KeybindingMouseBinding|nil
---@param value2 KeybindingV2Value|KeybindingKeyboardBinding|KeybindingMouseBinding|nil
---@return boolean
function KeybindingManager:AreBindingsEqual(value1, value2)
    return self:GetBindingIdentity(value1) == self:GetBindingIdentity(value2)
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

return KeybindingManager
