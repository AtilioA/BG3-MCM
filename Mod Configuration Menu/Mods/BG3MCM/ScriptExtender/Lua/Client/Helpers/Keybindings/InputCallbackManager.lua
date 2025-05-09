local RX = {
    Subject = Ext.Require("Lib/reactivex/subjects/subject.lua"),
    ReplaySubject = Ext.Require("Lib/reactivex/subjects/replaysubject.lua")
}

InputCallbackManager = {}

-- Create ReactiveX subjects to wrap input events.
InputCallbackManager._KeyInputSubject = RX.Subject.Create()

-- Table to hold pending callback registrations.
InputCallbackManager._PendingKeybindingCallbacks = {}
-- Emit once keybindings are loaded.
InputCallbackManager.KeybindingsLoadedSubject = RX.ReplaySubject.Create(1)

--- Registers a keybinding callback, queued for registration once keybindings are loaded.
--- @param modUUID string The mod's unique identifier.
--- @param actionId string The key of the action.
--- @param callback function The callback to invoke when that keybinding is triggered.
function InputCallbackManager.SetKeybindingCallback(modUUID, actionId, callback)
    -- Queue the registration of callbacks for later processing.
    table.insert(InputCallbackManager._PendingKeybindingCallbacks,
        { modUUID = modUUID, actionId = actionId, callback = callback })

    -- Subscribe to the KeybindingsLoadedSubject to register pending callbacks when keybindings are loaded.
    -- if InputCallbackManager._KeybindingsLoadedSubscribed then return end

    InputCallbackManager._KeybindingsLoadedSubscribed = true
    InputCallbackManager.KeybindingsLoadedSubject:Subscribe(function(loaded)
        if not loaded then return end

        -- Once keybindings are loaded, register all pending callbacks.
        for _, entry in ipairs(InputCallbackManager._PendingKeybindingCallbacks) do
            local success = InputCallbackManager.RegisterKeybinding(entry.modUUID, entry.actionId, entry.callback)
            if success then
                MCMPrint(2,
                    string.format("Registered keybinding callback for action '%s' (mod '%s')", entry.actionId,
                        entry.modUUID))
            else
                MCMWarn(0,
                    string.format("Failed to register keybinding callback for action '%s' (mod '%s')", entry
                        .actionId, entry.modUUID))
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
        InputCallbackManager._KeyInputSubject:OnNext(e)
    end)

    -- Subscribe to local subjects so that input events are dispatched via the registry.
    InputCallbackManager._KeyInputSubject:Subscribe(function(e)
        KeybindingsRegistry.DispatchKeyboardEvent(e)
    end)
end

--- Registers a keyboard/mouse callback by delegating to the registry.
--- @param modUUID string
--- @param actionId string
--- @param callback function
function InputCallbackManager.RegisterKeybinding(modUUID, actionId, callback)
    return KeybindingsRegistry.RegisterCallback(modUUID, actionId, "KeyboardMouse", callback)
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

return InputCallbackManager
