local NativeKeybindings = Ext.Require("Client/Helpers/Keybindings/NativeKeybindings.lua")

---@class KeybindingConflictService
KeybindingConflictService = _Class:Create("KeybindingConflictService", nil)

---Compares keyboard or mouse bindings by device, primary input, and modifier set.
---@param binding1 KeybindingKeyboardBinding|KeybindingMouseBinding|KeybindingV2Value|string|nil
---@param binding2 KeybindingKeyboardBinding|KeybindingMouseBinding|KeybindingV2Value|string|nil
---@return boolean
function KeybindingConflictService:AreKeybindingsEqual(binding1, binding2)
    local active1 = KeybindingManager:GetActiveV2Binding(binding1)
    local active2 = KeybindingManager:GetActiveV2Binding(binding2)
    if not active1 or not active2 then return active1 == nil and active2 == nil end
    return KeybindingsRegistry.NormalizeBinding(active1) == KeybindingsRegistry.NormalizeBinding(active2)
end

---Checks MCM and native bindings for a conflict.
---@param keybinding KeybindingKeyboardBinding|KeybindingMouseBinding|KeybindingV2Value|string|nil
---@param currentMod KeybindingUIMod
---@param currentAction KeybindingUIAction
---@param inputType string
---@return table|nil
function KeybindingConflictService:CheckForConflicts(keybinding, currentMod, currentAction, inputType)
    if inputType ~= "KeyboardMouse" or currentAction.AllowConflict
        or not KeybindingManager:GetActiveV2Binding(keybinding) then
        return nil
    end
    return self:CheckMCMForConflicts(keybinding, currentAction, currentMod and currentMod.ModUUID)
        or self:CheckNativeForConflicts(keybinding)
end

---Checks MCM-defined bindings for a conflict.
---@param keybinding KeybindingKeyboardBinding|KeybindingMouseBinding|KeybindingV2Value|string|nil
---@param currentAction KeybindingUIAction
---@param currentModUUID? string
---@return table|nil
function KeybindingConflictService:CheckMCMForConflicts(keybinding, currentAction, currentModUUID)
    local registry = KeybindingsRegistry.GetRegistry()
    for modUUID, actions in pairs(registry) do
        for actionId, action in pairs(actions) do
            if actionId ~= "_keybindingSortMode" then
                local actionBinding = KeybindingManager:GetActiveV2Binding({
                    Mouse = action.mouseBinding,
                    Keyboard = action.keyboardBinding
                })
                if not (modUUID == currentModUUID and actionId == currentAction.ActionId)
                    and action.allowConflict ~= true
                    and self:AreKeybindingsEqual(keybinding, actionBinding) then
                    return { ActionName = action.actionName, Keybinding = actionBinding }
                end
            end
        end
    end
    return nil
end

---@param modifiers table|nil
---@return string[]
local function copyModifiers(modifiers)
    local result = {}
    for _, modifier in ipairs(modifiers or {}) do
        table.insert(result, tostring(modifier))
    end
    return result
end

---Checks confidently mapped live native bindings for an exact conflict.
---@param keybinding KeybindingKeyboardBinding|KeybindingMouseBinding|KeybindingV2Value|string|nil
---@return table|nil
function KeybindingConflictService:CheckNativeForConflicts(keybinding)
    local active = KeybindingManager:GetActiveV2Binding(keybinding)
    if not active then return nil end

    local nativeData = NativeKeybindings.GetAll()
    for _, nativeAction in ipairs(nativeData.Public or {}) do
        for _, binding in ipairs(nativeAction.Bindings or {}) do
            local transformed = nil
            if active.Key and binding.InputType == "Keyboard" then
                transformed = { Key = tostring(binding.InputId), ModifierKeys = copyModifiers(binding.Modifiers) }
            elseif active.Button and binding.InputType == "Mouse" then
                local button = NativeKeybindings.GetVerifiedMouseButton(binding.InputId)
                if button then
                    transformed = { Button = button, ModifierKeys = copyModifiers(binding.Modifiers) }
                end
            end

            if transformed and self:AreKeybindingsEqual(active, transformed) then
                return { ActionName = nativeAction.EventName, Keybinding = transformed }
            end
        end
    end
    return nil
end

return KeybindingConflictService
