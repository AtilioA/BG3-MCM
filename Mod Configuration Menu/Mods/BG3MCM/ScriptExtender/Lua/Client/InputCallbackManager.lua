-- InputCallbackManager.lua

InputCallbackManager = {}

-- Internal registry organized by input type.
local InputCallbackRegistry = {
    KeyboardMouse = {}, -- keys are normalized binding strings (e.g., "CTRL+T")
    Controller    = {}  -- keys are normalized controller binding strings (e.g., "CONTROLLER1")
}

------------------------------------------------------------
-- Helper Functions
------------------------------------------------------------

-- For keyboard/mouse, normalize a keybinding table.
function InputCallbackManager:NormalizeKeybindingTable(binding)
    -- Expecting binding to be a table with 'ScanCode' and 'Modifier'
    _D(binding)
    if type(binding) ~= "table" or not binding.Key then
        _D("Invalid keybinding. Expected a table with a 'Key' field.")
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

-- Normalize controller binding string.
local function NormalizeControllerBindingString(binding)
    return binding:gsub("%s+", ""):upper()
end

------------------------------------------------------------
-- Registration API (Refactored)
------------------------------------------------------------

--- Registers a keyboard/mouse callback.
--- This function now looks up the keybinding from the global registry.
--- @param modUUID string The mod identifier (same as mod.ModName).
--- @param actionName string A name for the action.
--- @param callback function The function to call when this keybinding is triggered.
--- @return boolean True if registration succeeded, false if there was a conflict.
function InputCallbackManager.RegisterKeybinding(modUUID, actionName, callback)
    local modRegistry = GlobalKeybindingsRegistry[modUUID]
    if not modRegistry then
        print(string.format("[InputCallbackManager] No keybindings registered for mod '%s'.", modUUID))
        return false
    end

    local keybinding = modRegistry[actionName]
    if not keybinding then
        print(string.format("[InputCallbackManager] No keybinding found for action '%s' in mod '%s'.", actionName,
            modUUID))
        return false
    end

    _D("Registration")
    _D(keybinding)
    _D(InputCallbackRegistry.KeyboardMouse)
    local normalized = InputCallbackManager:NormalizeKeybindingTable(keybinding)
    if not normalized then return false end

    if InputCallbackRegistry.KeyboardMouse[normalized] then
        print(string.format(
            "[InputCallbackManager] Conflict: Keybinding '%s' already registered by mod '%s' for action '%s'.",
            normalized, InputCallbackRegistry.KeyboardMouse[normalized].modUUID,
            InputCallbackRegistry.KeyboardMouse[normalized].actionName))
        return false
    end

    InputCallbackRegistry.KeyboardMouse[normalized] = {
        modUUID    = modUUID,
        actionName = actionName,
        callback   = callback,
        keybinding = keybinding,
        normalized = normalized
    }
    print(string.format("[InputCallbackManager] Registered keybinding '%s' for mod '%s', action '%s'.",
        normalized, modUUID, actionName))
    return true
end

--- Registers a controller callback.
--- (Assumes that the controller binding is provided as a string directly on the action.)
--- @param modUUID string The mod identifier.
--- @param actionName string A name for the action.
--- @param controllerBinding string The controller binding string (if not, you could similarly look it up from a registry).
--- @param callback function The function to call when this binding is triggered.
--- @return boolean True if registration succeeded, false if there was a conflict.
function InputCallbackManager.RegisterControllerBinding(modUUID, actionName, controllerBinding, callback)
    local normalized = NormalizeControllerBindingString(controllerBinding)
    if InputCallbackRegistry.Controller[normalized] then
        print(string.format(
            "[InputCallbackManager] Conflict: Controller binding '%s' already registered by mod '%s' for action '%s'.",
            normalized, InputCallbackRegistry.Controller[normalized].modUUID,
            InputCallbackRegistry.Controller[normalized].actionName))
        return false
    end

    InputCallbackRegistry.Controller[normalized] = {
        modUUID    = modUUID,
        actionName = actionName,
        callback   = callback,
        binding    = normalized
    }
    print(string.format("[InputCallbackManager] Registered controller binding '%s' for mod '%s', action '%s'.",
        normalized, modUUID, actionName))
    return true
end

------------------------------------------------------------
-- Unregistration API
------------------------------------------------------------

function InputCallbackManager.UnregisterKeybinding(modUUID, actionName)
    local modRegistry = GlobalKeybindingsRegistry[modUUID]
    if not modRegistry then return false end
    local keybinding = modRegistry[actionName]
    if not keybinding then return false end
    local normalized = InputCallbackManager:NormalizeKeybindingTable(keybinding)
    local entry = InputCallbackRegistry.KeyboardMouse[normalized]
    if entry and entry.modUUID == modUUID then
        InputCallbackRegistry.KeyboardMouse[normalized] = nil
        print(string.format("[InputCallbackManager] Unregistered keybinding '%s' for mod '%s'.", normalized, modUUID))
        return true
    end
    return false
end

function InputCallbackManager.UnregisterControllerBinding(modUUID, controllerBinding)
    local normalized = NormalizeControllerBindingString(controllerBinding)
    local entry = InputCallbackRegistry.Controller[normalized]
    if entry and entry.modUUID == modUUID then
        InputCallbackRegistry.Controller[normalized] = nil
        print(string.format("[InputCallbackManager] Unregistered controller binding '%s' for mod '%s'.", normalized,
            modUUID))
        return true
    end
    return false
end

------------------------------------------------------------
-- Dispatching Logic
------------------------------------------------------------

--- Called when a key event occurs.
--- Expects an event table with:
---   - e.Event: string ("KeyUp", etc.)
---   - e.Key: string
---   - e.ModifierKeys: table of strings (active modifiers)
function InputCallbackManager.DispatchKeyInput(e)
    _D(InputCallbackRegistry.KeyboardMouse)
    if e.Event ~= "KeyUp" then return end -- Only trigger on key release

    -- Iterate over all registered keybindings and dispatch if pressed.
    for _, entry in pairs(InputCallbackRegistry.KeyboardMouse) do
        _D(entry)
        _D(e.Key)
        if KeybindingManager:IsKeybindingPressed(e, {
            ScanCode = entry.keybinding.Key,
            Modifier = entry.keybinding.ModifierKey
        }) then
            print(string.format("[InputCallbackManager] Dispatching keybinding '%s' for mod '%s', action '%s'.",
                entry.normalized, entry.modUUID, entry.actionName))
            entry.callback(e)
        end
    end
end

--- Called when a controller button event occurs.
--- Expects an event table with:
---   - e.Button: number or string representing the button.
---   - e.Pressed: boolean (true when pressed)
function InputCallbackManager.DispatchControllerInput(e)
    if not e.Pressed then return end
    local normalized = ("CONTROLLER" .. tostring(e.Button)):gsub("%s+", ""):upper()
    local entry = InputCallbackRegistry.Controller[normalized]
    if entry and type(entry.callback) == "function" then
        print(string.format("[InputCallbackManager] Dispatching controller binding '%s' for mod '%s', action '%s'.",
            normalized, entry.modUUID, entry.actionName))
        entry.callback(e)
    end
end

------------------------------------------------------------
-- Initialization / Global Event Subscriptions
------------------------------------------------------------

--- Call this once during startup to set up global input event listeners.
function InputCallbackManager.Initialize()
    -- Subscribe to key up events.
    Ext.Events.KeyInput:Subscribe(function(e)
        InputCallbackManager.DispatchKeyInput(e)
    end)
    -- Subscribe to controller button events.
    Ext.Events.ControllerButtonInput:Subscribe(function(e)
        InputCallbackManager.DispatchControllerInput(e)
    end)
    -- (Optional) Add additional event subscriptions if needed.
end

return InputCallbackManager
