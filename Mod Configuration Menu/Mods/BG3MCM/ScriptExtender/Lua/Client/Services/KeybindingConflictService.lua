local NativeKeybindings = Ext.Require("Client/Helpers/Keybindings/NativeKeybindings.lua")

---@class KeybindingConflictService
KeybindingConflictService = _Class:Create("KeybindingConflictService", nil)

local function isEmptyBinding(binding)
    if binding == nil or binding == "" or binding == UNASSIGNED_KEYBOARD_MOUSE_STRING then
        return true
    end
    if type(binding) == "table" then
        if not binding.Key or binding.Key == "" then
            return true
        end
    end
    return false
end

--- Compares two keybindings for equality after normalization
---@param binding1 Keybinding|string|nil
---@param binding2 Keybinding|string|nil
---@return boolean True if the keybindings are equal, false otherwise
function KeybindingConflictService:AreKeybindingsEqual(binding1, binding2)
    local normalized1, normalized2 = nil, nil

    -- Both unassigned
    if (binding1 == nil or binding1 == UNASSIGNED_KEYBOARD_MOUSE_STRING) and
        (binding2 == nil or binding2 == UNASSIGNED_KEYBOARD_MOUSE_STRING) then
        return true
    end

    -- One unassigned, the other not
    if (binding1 == nil or binding1 == UNASSIGNED_KEYBOARD_MOUSE_STRING) ~=
        (binding2 == nil or binding2 == UNASSIGNED_KEYBOARD_MOUSE_STRING) then
        return false
    end

    if type(binding1) == "table" and binding1.Key ~= nil then
        normalized1 = KeybindingsRegistry.NormalizeKeyboardBinding(binding1)
    end
    if type(binding2) == "table" and binding2.Key ~= nil then
        normalized2 = KeybindingsRegistry.NormalizeKeyboardBinding(binding2)
    end

    return normalized1 ~= nil and normalized2 ~= nil and normalized1 == normalized2
end

--- Checks if a keybinding conflicts with an existing action
---@param keybinding Keybinding|string|nil
---@param action table The action data to check against
---@param actionId string The ID of the action to check
---@param currentActionId string The ID of the current action to skip
---@return table|nil Conflicting action if found, nil otherwise
function KeybindingConflictService:CheckActionForConflict(keybinding, action, actionId, currentActionId)
    -- _D("Checking conflict between")
    -- _D(keybinding)
    if actionId == currentActionId or isEmptyBinding(action.keyboardBinding) then
        return nil
    end
    if isEmptyBinding(keybinding) then
        return nil
    end
    if self:AreKeybindingsEqual(keybinding, action.keyboardBinding) then
        return { ActionName = action.actionName }
    end
    return nil
end

--- Checks if a keybinding conflicts within a single mod
---@param keybinding Keybinding|string|nil
---@param actions table The actions table of a mod
---@param currentActionId string The ID of the current action to skip
---@return table|nil Conflicting action if found, nil otherwise
function KeybindingConflictService:CheckModForConflicts(keybinding, actions, currentActionId)
    for actionId, action in pairs(actions) do
        local conflict = self:CheckActionForConflict(keybinding, action, actionId, currentActionId)
        if conflict then
            return conflict
        end
    end
    return nil
end

--- Checks if a keybinding conflicts with existing bindings across all mods
---@param keybinding Keybinding|string
---@param currentMod table (unused)
---@param currentAction table The current action data
---@param inputType string The type of input ("KeyboardMouse")
---@return table|nil Conflicting action if found, nil otherwise
function KeybindingConflictService:CheckForConflicts(keybinding, currentMod, currentAction, inputType)
    if inputType ~= "KeyboardMouse" then
        return nil
    end

    local registry = KeybindingsRegistry.GetFilteredRegistry()
    local currentActionId = currentAction.ActionId

    for _, actions in pairs(registry) do
        local conflict = self:CheckModForConflicts(keybinding, actions, currentActionId)
        if conflict then
            return conflict
        end
    end

    -- Check native keybindings for conflicts
    local nativeData = NativeKeybindings.GetByDeviceType("Keyboard")
    if nativeData and nativeData.Public then
        for _, action in ipairs(nativeData.Public) do
            for _, binding in ipairs(action.Bindings or {}) do
                local mcmAction = {
                    ActionId = action.EventName,
                    ActionName = action.Name,
                    keyboardBinding = binding,
                    enabled = true,
                    defaultKeyboardBinding = binding,
                }
                local conflict = self:CheckActionForConflict(keybinding, mcmAction, action.EventName, currentActionId)
                if conflict then
                    return conflict
                end
            end
        end
    end

    return nil
end

return KeybindingConflictService
