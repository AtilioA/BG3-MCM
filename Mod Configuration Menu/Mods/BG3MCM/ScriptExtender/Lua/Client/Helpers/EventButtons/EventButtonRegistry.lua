local RX = {
    BehaviorSubject = Ext.Require("Lib/reactivex/subjects/behaviorsubject.lua")
}

---@class EventButtonRegistry
EventButtonRegistry = {
    Registry = {},
}

-- BehaviorSubject to emit registry changes.
local subject = RX.BehaviorSubject.Create(EventButtonRegistry.Registry)

--- Register a callback for an event button.
---@param modUUID string The mod's UUID.
---@param settingId string The event button setting ID.
---@param callback function The callback to execute.
---@return boolean success
function EventButtonRegistry.RegisterCallback(modUUID, settingId, callback)
    if not modUUID or not settingId or type(callback) ~= "function" then
        MCMWarn(0, "Invalid parameters to EventButtonRegistry.RegisterCallback.")
        return false
    end

    EventButtonRegistry.Registry[modUUID] = EventButtonRegistry.Registry[modUUID] or {}
    EventButtonRegistry.Registry[modUUID][settingId] = { eventButtonCallback = callback }

    subject:OnNext(EventButtonRegistry.Registry)
    return true
end

--- Unregister a callback for an event button.
---@param modUUID string The mod's UUID.
---@param settingId string The event button setting ID.
---@return boolean success
function EventButtonRegistry.UnregisterCallback(modUUID, settingId)
    if EventButtonRegistry.Registry[modUUID] and EventButtonRegistry.Registry[modUUID][settingId] then
        EventButtonRegistry.Registry[modUUID][settingId] = nil
        subject:OnNext(EventButtonRegistry.Registry)
        return true
    end
    return false
end

--- Get the BehaviorSubject for registry updates.
---@return BehaviorSubject
function EventButtonRegistry.GetSubject()
    return subject
end

--- Get current registry table.
---@return table
function EventButtonRegistry.GetRegistry()
    return EventButtonRegistry.Registry
end

return EventButtonRegistry
