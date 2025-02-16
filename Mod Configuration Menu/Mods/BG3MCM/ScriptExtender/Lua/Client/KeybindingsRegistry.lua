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
    local mod = binding.ModifierKey and binding.ModifierKey:upper() or "NONE"
    local scan = binding.Key and binding.Key:upper() or ""
    if mod ~= "NONE" then
        return mod .. "+" .. scan
    else
        return scan
    end
end

function KeybindingsRegistry.NormalizeControllerBinding(binding)
    return binding:gsub("%s+", ""):upper()
end

--- Registers keybindings for one or more mods.
--- Expects an array of mod keybinding definitions.
function KeybindingsRegistry.RegisterModKeybindings(modKeybindings)
    for _, mod in ipairs(modKeybindings) do
        registry[mod.ModName] = registry[mod.ModName] or {}
        for _, action in ipairs(mod.Actions) do
            local keyboardNormalized = nil
            if action.KeyboardMouseBinding then
                keyboardNormalized = KeybindingsRegistry.NormalizeKeyboardBinding(action.KeyboardMouseBinding)
            end
            local controllerNormalized = nil
            if action.ControllerBinding and action.ControllerBinding ~= "" then
                controllerNormalized = KeybindingsRegistry.NormalizeControllerBinding(action.ControllerBinding)
            end
            registry[mod.ModName][action.ActionName] = {
                modUUID = mod.ModName,
                actionName = action.ActionName,
                keyboardBinding = keyboardNormalized,
                controllerBinding = controllerNormalized,
                defaultKeyboardBinding = action.DefaultKeyboardMouseBinding,
                defaultControllerBinding = action.DefaultControllerBinding,
            }
        end
    end
    keybindingsSubject:OnNext(registry)
end

--- Updates a binding for a given mod/action.
function KeybindingsRegistry.UpdateBinding(modUUID, actionName, newBinding, inputType)
    local modTable = registry[modUUID]
    if not modTable or not modTable[actionName] then
        print(string.format("No binding found for mod '%s', action '%s'.", modUUID, actionName))
        return false
    end

    if inputType == "KeyboardMouse" then
        modTable[actionName].keyboardBinding = newBinding
    elseif inputType == "Controller" then
        modTable[actionName].controllerBinding = newBinding
    end
    keybindingsSubject:OnNext(registry)
    return true
end

--- Registers a callback for a given binding.
function KeybindingsRegistry.RegisterCallback(modUUID, actionName, inputType, callback)
    local modTable = registry[modUUID]
    if not modTable or not modTable[actionName] then
        print(string.format("No binding found for mod '%s', action '%s'.", modUUID, actionName))
        return false
    end

    if inputType == "KeyboardMouse" then
        modTable[actionName].keyboardCallback = callback
    elseif inputType == "Controller" then
        modTable[actionName].controllerCallback = callback
    end
    keybindingsSubject:OnNext(registry)
    return true
end

--- Dispatch a keyboard event.
function KeybindingsRegistry.DispatchKeyboardEvent(e)
    if e.Event ~= "KeyDown" then return end
    -- For each registered keyboard binding, check if it matches.
    for modUUID, actions in pairs(registry) do
        for actionName, binding in pairs(actions) do
            if binding.keyboardBinding and KeybindingManager and
                KeybindingManager:IsKeybindingPressed(e, {
                    ScanCode = binding.keyboardBinding.Key,
                    Modifier = binding.keyboardBinding.ModifierKey
                }) then
                print(string.format("[KeybindingsRegistry] Dispatching keyboard binding '%s' for mod '%s', action '%s'.",
                    binding.keyboardBinding, modUUID, actionName))
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
        for actionName, binding in pairs(actions) do
            if binding.controllerBinding == normalized then
                print(string.format(
                    "[KeybindingsRegistry] Dispatching controller binding '%s' for mod '%s', action '%s'.",
                    normalized, modUUID, actionName))
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
