local RX = {
    Subject = Ext.Require("Lib/reactivex/subjects/subject.lua"),
    ReplaySubject = Ext.Require("Lib/reactivex/subjects/replaysubject.lua")
}

InputCallbackManager = {}

-- Create ReactiveX subjects to wrap input events.
InputCallbackManager._KeyInputSubject = RX.Subject.Create()
InputCallbackManager._ControllerInputSubject = RX.Subject.Create()

-- Table to hold pending callback registrations.
InputCallbackManager._PendingKeybindingCallbacks = {}
-- Emit once keybindings are loaded.
InputCallbackManager.KeybindingsLoadedSubject = RX.ReplaySubject.Create(1)

--- Registers a keybinding callback, queued for registration once keybindings are loaded.
--- @param modUUID string The mod's unique identifier.
---@param actionId string The key of the action.
---@param callback function The callback to invoke when that keybinding is triggered.
function InputCallbackManager.SetKeybindingCallback(modUUID, actionId, callback)
    -- Queue the registration of callbacks for later processing.
    table.insert(InputCallbackManager._PendingKeybindingCallbacks, { actionId = actionId, callback = callback })

    -- Subscribe to the KeybindingsLoadedSubject to register pending callbacks when keybindings are loaded.
    InputCallbackManager.KeybindingsLoadedSubject:Subscribe(function(loaded)
        if not loaded then return end

        -- Once keybindings are loaded, register all pending callbacks.
        for _, entry in ipairs(InputCallbackManager._PendingKeybindingCallbacks) do
            local success = InputCallbackManager.RegisterKeybinding(modUUID, entry.actionId, entry.callback)
            if success then
                MCMPrint(2, string.format("Registered keybinding callback for action '%s'", entry.actionId))
            else
                MCMWarn(0, string.format("Failed to register keybinding callback for action '%s'", entry.actionId))
            end
        end
        -- Clear the pending queue after processing.
        InputCallbackManager._PendingKeybindingCallbacks = {}
    end)
end

--- Initializes the manager: subscribes to global events and routes them into RX streams.
function InputCallbackManager.Initialize()
    -- Subscribe to Ext.Events and push events into local subjects.
    Ext.Events.KeyInput:Subscribe(function(e)
        -- TODO: allow configurable repeat events (author-defined)
        if e.Repeat == false then
            InputCallbackManager._KeyInputSubject:OnNext(e)
        end
    end)
    Ext.Events.ControllerButtonInput:Subscribe(function(e)
        InputCallbackManager._ControllerInputSubject:OnNext(e)
    end)

    -- Subscribe to local subjects so that input events are dispatched via the registry.
    InputCallbackManager._KeyInputSubject:Subscribe(function(e)
        KeybindingsRegistry.DispatchKeyboardEvent(e)
    end)
    InputCallbackManager._ControllerInputSubject:Subscribe(function(e)
        KeybindingsRegistry.DispatchControllerEvent(e)
    end)
end

--- Registers a keyboard/mouse callback by delegating to the registry.
--- @param modUUID string
--- @param actionId string
--- @param callback function
function InputCallbackManager.RegisterKeybinding(modUUID, actionId, callback)
    return KeybindingsRegistry.RegisterCallback(modUUID, actionId, "KeyboardMouse", callback)
end

--- Registers a controller callback.
function InputCallbackManager.RegisterControllerBinding(modUUID, actionId, controllerBinding, callback)
    if not KeybindingsRegistry.UpdateBinding(modUUID, actionId, controllerBinding, "Controller") then
        return false
    end
    return KeybindingsRegistry.RegisterCallback(modUUID, actionId, "Controller", callback)
end

--- Unregisters the keyboard callback.
function InputCallbackManager.UnregisterKeybinding(modUUID, actionId)
    local reg = KeybindingsRegistry.GetRegistry()
    if reg[modUUID] and reg[modUUID][actionId] then
        reg[modUUID][actionId].keyboardCallback = nil
        return true
    end
    return false
end

--- Unregisters the controller callback.
function InputCallbackManager.UnregisterControllerBinding(modUUID, actionId)
    local reg = KeybindingsRegistry.GetRegistry()
    if reg[modUUID] and reg[modUUID][actionId] then
        reg[modUUID][actionId].controllerCallback = nil
        return true
    end
    return false
end

return InputCallbackManager
