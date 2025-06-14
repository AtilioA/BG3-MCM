-- Manages the lifecycle and tracking of active notifications

---@class NotificationRegistry
---@field private _activeNotifications table<NotificationManager, boolean>
NotificationRegistry = _Class:Create("NotificationRegistry", nil, {
    _activeNotifications = {}
})

-- --- Finds an existing notification with the given title and message
-- ---@param title string The title to search for
-- ---@param message string The message to search for
-- ---@return NotificationManager|nil
-- function NotificationRegistry:FindExisting(title, message)
--     for notification, _ in pairs(self._activeNotifications) do
--         if notification and type(notification) == "table" and notification.title == title and notification.message == message then
--             return notification
--         end
--     end
--     return nil
-- end

--- Finds an existing notification with the given title
---@param title string The title to search for
---@return NotificationManager|nil
function NotificationRegistry:FindByTitle(title)
    for notification, _ in pairs(self._activeNotifications) do
        if notification and type(notification) == "table" and notification.title == title then
            return notification
        end
    end
    return nil
end

--- Adds a notification to the registry
---@param notification NotificationManager The notification to add
function NotificationRegistry:Add(notification)
    if not notification or not notification.id then return end

    -- Remove any existing notification with the same ID
    self:Remove(notification)
    self._activeNotifications[notification] = true
end

--- Removes a notification from the registry
---@param notification NotificationManager The notification to remove
---@return boolean True if the notification was found and removed
function NotificationRegistry:Remove(notification)
    if not notification then return false end

    if self._activeNotifications[notification] then
        self._activeNotifications[notification] = nil
        return true
    end
    return false
end

--- Gets the number of active notifications
---@return integer
function NotificationRegistry:Count()
    local count = 0
    for _ in pairs(self._activeNotifications) do
        count = count + 1
    end
    return count
end

return NotificationRegistry
