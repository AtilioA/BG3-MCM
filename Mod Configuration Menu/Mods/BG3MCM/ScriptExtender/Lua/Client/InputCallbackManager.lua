local RX = {
    Subject = Ext.Require("Lib/reactivex/subjects/subject.lua")
}

InputCallbackManager = {}

-- Create ReactiveX subjects to wrap input events.
-- local keyInputSubject = RX.Subject.Create()
-- local controllerInputSubject = RX.Subject.Create()

--- Initializes the manager: subscribes to global events and routes them into RX streams.
-- function InputCallbackManager.Initialize()
--     -- Subscribe to Ext.Events and push events into local subjects.
--     Ext.Events.KeyInput:Subscribe(function(e)
--         -- TODO: allow configurable repeat events (author-defined)
--         if e.Repeat == false then
--             keyInputSubject:OnNext(e)
--         end
--     end)
--     Ext.Events.ControllerButtonInput:Subscribe(function(e)
--         controllerInputSubject:OnNext(e)
--     end)

--     -- Subscribe to local subjects so that input events are dispatched via the registry.
--     keyInputSubject:Subscribe(function(e)
--         KeybindingsRegistry.DispatchKeyboardEvent(e)
--     end)
--     controllerInputSubject:Subscribe(function(e)
--         KeybindingsRegistry.DispatchControllerEvent(e)
--     end)
-- end

--- Registers a keyboard/mouse callback by delegating to the registry.
function InputCallbackManager.RegisterKeybinding(modUUID, actionName, callback)
    return KeybindingsRegistry.RegisterCallback(modUUID, actionName, "KeyboardMouse", callback)
end

--- Registers a controller callback.
function InputCallbackManager.RegisterControllerBinding(modUUID, actionName, controllerBinding, callback)
    if not KeybindingsRegistry.UpdateBinding(modUUID, actionName, controllerBinding, "Controller") then
        return false
    end
    return KeybindingsRegistry.RegisterCallback(modUUID, actionName, "Controller", callback)
end

--- Unregisters the keyboard callback.
function InputCallbackManager.UnregisterKeybinding(modUUID, actionName)
    local reg = KeybindingsRegistry.GetRegistry()
    if reg[modUUID] and reg[modUUID][actionName] then
        reg[modUUID][actionName].keyboardCallback = nil
        return true
    end
    return false
end

--- Unregisters the controller callback.
function InputCallbackManager.UnregisterControllerBinding(modUUID, actionName)
    local reg = KeybindingsRegistry.GetRegistry()
    if reg[modUUID] and reg[modUUID][actionName] then
        reg[modUUID][actionName].controllerCallback = nil
        return true
    end
    return false
end

return InputCallbackManager
