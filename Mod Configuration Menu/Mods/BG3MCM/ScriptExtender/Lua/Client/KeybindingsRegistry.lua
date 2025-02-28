local RX = {
    BehaviorSubject = Ext.Require("Lib/reactivex/subjects/behaviorsubject.lua")
}

KeybindingsRegistry = {}

-- Internal registry: a table mapping mod UUID to its actions.
local registry = {}

-- A BehaviorSubject that always holds the current registry state.
local keybindingsSubject = RX.BehaviorSubject.Create(registry)

-- Utility functions for normalizing bindings.
function KeybindingsRegistry.NormalizeKeyboardBinding(binding)
    if type(binding) ~= "table" or not binding.Key then
        print("Invalid keyboard binding, expected a table with a 'Key' field.")
        return nil
    end
    local mod = (binding.ModifierKeys and type(binding.ModifierKeys) == "table") and #binding.ModifierKeys > 0 and
        table.concat(binding.ModifierKeys, "+"):upper() or "NONE"
    local scan = binding.Key:upper()
    if mod ~= "NONE" then
        return mod .. "+" .. scan
    else
        return scan
    end
end

--- Registers keybindings for one or more mods.
--- Expects an array of mod keybinding definitions.
function KeybindingsRegistry.RegisterModKeybindings(modKeybindings)
    for _, mod in ipairs(modKeybindings) do
        registry[mod.ModUUID] = registry[mod.ModUUID] or {}
        for _, action in ipairs(mod.Actions) do
            local keyboardNormalized = nil
            registry[mod.ModUUID][action.ActionId] = {
                modUUID = mod.ModUUID,
                actionName = action.ActionName,
                actionId = action.ActionId,
                keyboardBinding = action.KeyboardMouseBinding,
                defaultKeyboardBinding = action.DefaultKeyboardMouseBinding,
            }
        end
    end
    keybindingsSubject:OnNext(registry)
end

--- Updates a binding for a given mod/action.
function KeybindingsRegistry.UpdateBinding(modUUID, actionId, newBinding, inputType)
    local modTable = registry[modUUID]
    if not modTable or not modTable[actionId] then
        print(string.format("No binding found to update for mod '%s', action '%s'.", modUUID, actionId))
        return false
    end

    if inputType == "KeyboardMouse" then
        modTable[actionId].keyboardBinding = newBinding
    end
    keybindingsSubject:OnNext(registry)
    return true
end

--- Registers a callback for a given binding.
function KeybindingsRegistry.RegisterCallback(modUUID, actionId, inputType, callback)
    local modTable = registry[modUUID]
    if not modTable or not modTable[actionId] then
        MCMWarn(0, string.format("No binding found for mod '%s', action '%s'.", modUUID, actionId))
        return false
    end

    if inputType == "KeyboardMouse" then
        modTable[actionId].keyboardCallback = callback
    end
    keybindingsSubject:OnNext(registry)
    return true
end

--- Dispatch a keyboard event.
function KeybindingsRegistry.DispatchKeyboardEvent(e)
    if e.Event ~= "KeyDown" then return end
    local triggered = {}
    -- Collect all bindings that match the key event.
    for modUUID, actions in pairs(registry) do
        for actionId, binding in pairs(actions) do
            if binding.keyboardBinding and KeybindingManager and
                KeybindingManager:IsKeybindingPressed(e, {
                    ScanCode = binding.keyboardBinding.Key,
                    Modifier = binding.keyboardBinding.ModifierKeys
                }) then
                table.insert(triggered, binding)
            end
        end
    end
    if #triggered > 1 then
        local keybindingStr = KeyPresentationMapping:GetKBViewKey(triggered[1].keyboardBinding)
        if not keybindingStr then
            keybindingStr = ""
        end
        NotificationManager:CreateIMGUINotification("Keybinding_Conflict" .. Ext.Math.Random(), 'warning',
            "Keybinding conflict",
            "Keybinding " .. keybindingStr .. " is bound to multiple actions.\nOpen MCM and rebind conflicting keys.", {
                duration = 10,
                dontShowAgainButton = false
            }, ModuleUUID)
        MCMClientState:ToggleMCMWindow(false)
        if triggered[1].keyboardCallback then
            triggered[1].keyboardCallback(e)
        end
    elseif #triggered == 1 then
        if triggered[1].keyboardCallback then
            MCMPrint(1, "Dispatching keyboard binding for mod '" ..
                triggered[1].modUUID .. "', action '" .. triggered[1].actionName .. "'.")
            triggered[1].keyboardCallback(e)
        end
    end
end

--- Exposes the registry’s BehaviorSubject so others can subscribe.
function KeybindingsRegistry.GetSubject()
    return keybindingsSubject
end

--- Returns the full registry table.
function KeybindingsRegistry.GetRegistry()
    return registry
end
