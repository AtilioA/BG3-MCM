local RX = {
    BehaviorSubject = Ext.Require("Lib/reactivex/subjects/behaviorsubject.lua")
}

---@alias EventButtonRegistryEntry { eventButtonCallback: function, disabled: boolean, disabledTooltip: string }

---@class EventButtonRegistry
---@field Registry table<string, table<string, EventButtonRegistryEntry>>
EventButtonRegistry = {
    Registry = {},
    Widgets = {},
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

--- Set the disabled state of an event button
---@param modUUID string The mod's UUID
---@param settingId string The event button setting ID
---@param disabled boolean Whether the button should be disabled
---@param tooltipText? string Optional tooltip text to show when disabled (only used when disabling)
---@return boolean success True if the state was updated
function EventButtonRegistry.SetDisabled(modUUID, settingId, disabled, tooltipText)
    if not modUUID or not settingId then
        MCMWarn(0, "Invalid parameters to EventButtonRegistry.SetDisabled")
        return false
    end

    -- Ensure the mod and setting exist in the registry
    if not EventButtonRegistry.Registry[modUUID] or not EventButtonRegistry.Registry[modUUID][settingId] then
        MCMWarn(0, string.format("Button not found: mod='%s', setting='%s'", tostring(modUUID), tostring(settingId)))
        return false
    end

    -- Update disabled state and tooltip
    local entry = EventButtonRegistry.Registry[modUUID][settingId]
    entry.disabled = disabled

    if disabled then
        -- When disabling, store the current tooltip if not already stored
        if tooltipText ~= nil then
            entry.disabledTooltip = tooltipText
        elseif entry.disabledTooltip == nil then
            entry.disabledTooltip = ""
        end
    else
        -- When re-enabling, clear the disabled tooltip to restore the original
        entry.disabledTooltip = nil
    end

    -- Notify subscribers of the change
    subject:OnNext(EventButtonRegistry.Registry)
    return true
end

--- Check if an event button is disabled
---@param modUUID string The mod's UUID
---@param settingId string The event button setting ID
---@return boolean|nil isDisabled True if disabled, false if enabled, nil if not found
function EventButtonRegistry.IsDisabled(modUUID, settingId)
    if not modUUID or not settingId then
        MCMWarn(0, "Invalid parameters to EventButtonRegistry.IsDisabled")
        return nil
    end

    if EventButtonRegistry.Registry[modUUID] and EventButtonRegistry.Registry[modUUID][settingId] then
        return EventButtonRegistry.Registry[modUUID][settingId].disabled == true
    end
    return nil
end

--- Get a widget by mod UUID and setting ID
---@param modUUID string
---@param settingId string
---@return table|nil widget
function EventButtonRegistry.GetWidget(modUUID, settingId)
    if not EventButtonRegistry.Widgets[modUUID] then return nil end
    return EventButtonRegistry.Widgets[modUUID][settingId]
end

--- Set a widget reference for a specific button
---@param modUUID string
---@param settingId string
---@param widget table The widget to store
function EventButtonRegistry.SetWidget(modUUID, settingId, widget)
    if not modUUID or not settingId or not widget then return end

    if not EventButtonRegistry.Widgets[modUUID] then
        EventButtonRegistry.Widgets[modUUID] = {}
    end
    EventButtonRegistry.Widgets[modUUID][settingId] = widget
end

--- Remove a widget reference
---@param modUUID string
---@param settingId string
function EventButtonRegistry.RemoveWidget(modUUID, settingId)
    if EventButtonRegistry.Widgets[modUUID] then
        EventButtonRegistry.Widgets[modUUID][settingId] = nil
    end
end

--- Show feedback for an event button
---@param modUUID string
---@param settingId string
---@param message string
---@param feedbackType? string The type of feedback ("success", "error", "info", "warning"). Defaults to "info".
---@param durationInMs? number How long to display the feedback in milliseconds. Defaults to 5000ms.
---@return boolean success
function EventButtonRegistry.ShowFeedback(modUUID, settingId, message, feedbackType, durationInMs)
    if not modUUID or not settingId or not message then return false end
    if not feedbackType then feedbackType = "info" end
    if not durationInMs then durationInMs = ClientGlobals.MCM_EVENT_BUTTON_FEEDBACK_DURATION end

    local widget = EventButtonRegistry.GetWidget(modUUID, settingId)

    if not widget then
        MCMWarn(0, string.format("Widget not found for mod='%s', setting='%s'", tostring(modUUID), tostring(settingId)))
        return false
    end

    -- Call the UpdateFeedback method on the widget with all parameters
    if widget.UpdateFeedback then
        widget:UpdateFeedback(message, feedbackType, durationInMs)
        return true
    end

    return false
end

return EventButtonRegistry
