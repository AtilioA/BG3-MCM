local RX = {
    Subject = Ext.Require("Lib/reactivex/subjects/subject.lua"),
    ReplaySubject = Ext.Require("Lib/reactivex/subjects/replaysubject.lua")
}

InputCallbackManager = {}

-- Create ReactiveX subjects to wrap input events.
InputCallbackManager._KeyInputSubject = RX.Subject.Create()
InputCallbackManager._MouseInputSubject = RX.Subject.Create()
InputCallbackManager._HeldModifiers = {}
local INPUT_CLEANUP_GAME_STATES = {
    [Ext.Enums.ClientGameState.StartLoading] = true,
    [Ext.Enums.ClientGameState.LoadSession] = true,
    [Ext.Enums.ClientGameState.LoadLevel] = true,
    [Ext.Enums.ClientGameState.SwapLevel] = true,
    [Ext.Enums.ClientGameState.UnloadLevel] = true,
    [Ext.Enums.ClientGameState.UnloadSession] = true,
    [Ext.Enums.ClientGameState.Disconnect] = true
}

-- Table to hold pending callback registrations.
InputCallbackManager._PendingKeybindingCallbacks = {}
-- Emit once keybindings are loaded.
InputCallbackManager.KeybindingsLoadedSubject = RX.ReplaySubject.Create(1)

--- Registers a keybinding callback, queued for registration once keybindings are loaded.
--- REVIEW: Maybe we don't want separate event type registrations. Still thinking about that.
---@param modUUID string The mod's unique identifier.
---@param actionId string The key of the action.
---@param callback fun(e:EclLuaKeyInputEvent|EclLuaMouseButtonEvent) The raw input event callback.
---@param eventType? string Optional event type: "KeyDown", "KeyUp", or nil for both (backward compatible)
function InputCallbackManager.SetKeybindingCallback(modUUID, actionId, callback, eventType)
    if InputCallbackManager._KeybindingsLoaded then
        InputCallbackManager.RegisterKeybinding(modUUID, actionId, callback, eventType)
        return
    end

    -- Queue the registration of callbacks for later processing.
    table.insert(InputCallbackManager._PendingKeybindingCallbacks,
        { modUUID = modUUID, actionId = actionId, callback = callback, eventType = eventType })

    -- Subscribe to the KeybindingsLoadedSubject to register pending callbacks when keybindings are loaded.
    if InputCallbackManager._KeybindingsLoadedSubscribed then return end

    InputCallbackManager._KeybindingsLoadedSubscribed = true
    InputCallbackManager.KeybindingsLoadedSubject:Subscribe(function(loaded)
        if not loaded then return end
        InputCallbackManager._KeybindingsLoaded = true

        -- Once keybindings are loaded, register all pending callbacks.
        for _, entry in ipairs(InputCallbackManager._PendingKeybindingCallbacks) do
            local success = InputCallbackManager.RegisterKeybinding(entry.modUUID, entry.actionId, entry.callback,
                entry.eventType)
            if success then
                MCMPrint(2, "Registered keybinding callback for action '%s' (mod '%s')", entry.actionId,
                    entry.modUUID)
            else
                MCMWarn(0, "Failed to register keybinding callback for action '%s' (mod '%s')", entry
                    .actionId, entry.modUUID)
            end
        end
        -- Clear the pending queue after processing.
        InputCallbackManager._PendingKeybindingCallbacks = {}
    end)
end

---Returns the currently held keyboard modifiers in stable order.
---@return string[]
function InputCallbackManager.GetHeldModifiers()
    local modifiers = {}
    for modifier in pairs(InputCallbackManager._HeldModifiers) do
        table.insert(modifiers, modifier)
    end
    table.sort(modifiers)
    return modifiers
end

---Returns whether an input lifecycle must be reset for a client game state.
---@param state unknown
---@return boolean
function InputCallbackManager.IsInputCleanupGameState(state)
    return INPUT_CLEANUP_GAME_STATES[state] == true
end

---Clears held, captured, and matched input state across game/session transitions.
function InputCallbackManager.ResetInputState()
    InputCallbackManager._HeldModifiers = {}
    if KeybindingCaptureSession then KeybindingCaptureSession.Reset("input-reset") end
    KeybindingsRegistry.ResetInputState()
end

--- Registers a keybinding callback for KeyDown events only.
---@param modUUID string The mod's unique identifier.
---@param actionId string The key of the action.
---@param callback fun(e:EclLuaKeyInputEvent|EclLuaMouseButtonEvent) The raw key-down or mouse-press callback.
function InputCallbackManager.SetKeyDownCallback(modUUID, actionId, callback)
    InputCallbackManager.SetKeybindingCallback(modUUID, actionId, callback, "KeyDown")
end

--- Registers a keybinding callback for KeyUp events only.
---@param modUUID string The mod's unique identifier.
---@param actionId string The key of the action.
---@param callback fun(e:EclLuaKeyInputEvent|EclLuaMouseButtonEvent) The raw key-up or mouse-release callback.
function InputCallbackManager.SetKeyUpCallback(modUUID, actionId, callback)
    InputCallbackManager.SetKeybindingCallback(modUUID, actionId, callback, "KeyUp")
end

--- Initializes the manager: subscribes to global events and routes them into RX streams.
function InputCallbackManager.Initialize()
    if InputCallbackManager._initialized then return end
    InputCallbackManager._initialized = true

    -- Subscribe to Ext.Events and push events into local subjects.
    Ext.Events.KeyInput:Subscribe(function(e)
        local key = tostring(e.Key):upper()
        if KeybindingManager:IsActiveModifier(key) then
            if e.Event == "KeyDown" then
                InputCallbackManager._HeldModifiers[key] = true
            elseif e.Event == "KeyUp" then
                InputCallbackManager._HeldModifiers[key] = nil
            end
        end
        if KeybindingCaptureSession.ConsumeClaimedRelease("Keyboard", key, e.Event == "KeyUp") then
            e:PreventAction()
            return
        end
        if KeybindingCaptureSession.IsActive() then return end
        InputCallbackManager._KeyInputSubject:OnNext(e)
    end)
    Ext.Events.MouseButtonInput:Subscribe(function(e)
        if KeybindingCaptureSession.ConsumeClaimedRelease("Mouse", e.Button, not e.Pressed) then
            e:PreventAction()
            return
        end
        if KeybindingCaptureSession.IsActive() then return end
        InputCallbackManager._MouseInputSubject:OnNext(e)
    end)
    Ext.Events.GameStateChanged:Subscribe(function(e)
        if InputCallbackManager.IsInputCleanupGameState(e.ToState) then
            InputCallbackManager.ResetInputState()
        end
    end)

    -- Subscribe to local subjects so that input events are dispatched via the registry.
    InputCallbackManager._KeyInputSubject:Subscribe(function(e)
        KeybindingsRegistry.DispatchKeyboardEvent(e)
    end)
    InputCallbackManager._MouseInputSubject:Subscribe(function(e)
        KeybindingsRegistry.DispatchMouseEvent(e, InputCallbackManager.GetHeldModifiers())
    end)
end

--- Registers a keyboard/mouse callback by delegating to the registry.
--- @param modUUID string
--- @param actionId string
--- @param callback fun(e:EclLuaKeyInputEvent|EclLuaMouseButtonEvent)
--- @param eventType? string Optional event type: "KeyDown", "KeyUp", or nil for both
function InputCallbackManager.RegisterKeybinding(modUUID, actionId, callback, eventType)
    return KeybindingsRegistry.RegisterCallback(modUUID, actionId, "KeyboardMouse", callback, eventType)
end

--- Unregisters the keyboard callback.
function InputCallbackManager.UnregisterKeybinding(modUUID, actionId)
    local reg = KeybindingsRegistry.GetRegistry()
    if reg[modUUID] and reg[modUUID][actionId] then
        reg[modUUID][actionId].keyboardCallback = nil
        reg[modUUID][actionId].keyDownCallback = nil
        reg[modUUID][actionId].keyUpCallback = nil
        return true
    end
    return false
end

return InputCallbackManager
