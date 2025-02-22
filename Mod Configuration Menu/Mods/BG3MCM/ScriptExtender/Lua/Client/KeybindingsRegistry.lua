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

function KeybindingsRegistry.NormalizeControllerBinding(binding)
    if type(binding) ~= "table" or not binding.Buttons then
        print("Invalid controller binding, expected a table with a 'Buttons' field.")
        return nil
    end
    local normalizedButtons = {}
    for _, button in ipairs(binding.Buttons) do
        table.insert(normalizedButtons, button:gsub("%s+", ""):upper())
    end
    return normalizedButtons
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
                controllerBinding = action.ControllerBinding,
                defaultKeyboardBinding = action.DefaultKeyboardMouseBinding,
                defaultControllerBinding = action.DefaultControllerBinding,
            }
        end
    end
    keybindingsSubject:OnNext(registry)
end

--- Updates a binding for a given mod/action.
function KeybindingsRegistry.UpdateBinding(modUUID, actionId, newBinding, inputType)
    local modTable = registry[modUUID]
    _D(modTable)
    if not modTable or not modTable[actionId] then
        print(string.format("No binding found to update for mod '%s', action '%s'.", modUUID, actionId))
        return false
    end

    if inputType == "KeyboardMouse" then
        modTable[actionId].keyboardBinding = newBinding
    elseif inputType == "Controller" then
        modTable[actionId].controllerBinding = newBinding
    end
    keybindingsSubject:OnNext(registry)
    return true
end

--- Registers a callback for a given binding.
function KeybindingsRegistry.RegisterCallback(modUUID, actionId, inputType, callback)
    local modTable = registry[modUUID]
    if not modTable or not modTable[actionId] then
        print(string.format("No binding found for mod '%s', action '%s'.", modUUID, actionId))
        return false
    end

    if inputType == "KeyboardMouse" then
        modTable[actionId].keyboardCallback = callback
    elseif inputType == "Controller" then
        modTable[actionId].controllerCallback = callback
    end
    keybindingsSubject:OnNext(registry)
    return true
end

--- Dispatch a keyboard event.
function KeybindingsRegistry.DispatchKeyboardEvent(e)
    if e.Event ~= "KeyDown" then return end
    -- For each registered keyboard binding, check if it matches.
    for modUUID, actions in pairs(registry) do
        for actionId, binding in pairs(actions) do
            if binding.keyboardBinding and KeybindingManager and
                KeybindingManager:IsKeybindingPressed(e, {
                    ScanCode = binding.keyboardBinding.Key,
                    Modifier = binding.keyboardBinding.ModifierKeys
                }) then
                print(string.format("[KeybindingsRegistry] Dispatching keyboard binding '%s' for mod '%s', action '%s'.",
                    binding.keyboardBinding.Key, modUUID, actionId))
                if binding.keyboardCallback then
                    binding.keyboardCallback(e)
                end
            end
        end
    end
end

--- Dispatch a controller event.
function KeybindingsRegistry.DispatchControllerEvent(e)
    if not e.Pressed then return end
    local normalized = ("CONTROLLER" .. tostring(e.Button)):gsub("%s+", ""):upper()
    for modUUID, actions in pairs(registry) do
        for actionId, binding in pairs(actions) do
            if binding.controllerBinding == normalized then
                print(string.format(
                    "[KeybindingsRegistry] Dispatching controller binding '%s' for mod '%s', action '%s'.",
                    normalized, modUUID, actionId))
                if binding.controllerCallback then
                    binding.controllerCallback(e)
                end
            end
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
