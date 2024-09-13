-- TODO: Move somewhere else

---@class NotificationPreferences
---@field NotificationPreferencesFilePath string
NotificationPreferences = _Class:Create("NotificationPreferences", nil, {
    NotificationPreferencesFilePath = "notification_preferences.json"
})

function NotificationPreferences:LoadUserPreferences()
    local data = JsonLayer:LoadJSONFile(self.NotificationPreferencesFilePath)
    return data or {}
end

local function storeUserPreference(key, value)
    if key == nil or value == nil then
        return
    end

    local preferences = NotificationPreferences:LoadUserPreferences()
    if preferences == nil then
        preferences = {}
    end

    preferences[key] = value
    JsonLayer:SaveJSONFile(NotificationPreferences.NotificationPreferencesFilePath, preferences)
end

function NotificationPreferences:StoreUserDontShowPreference(key)
    storeUserPreference(key, { show = false })
end

function NotificationPreferences:ShouldShowNotification(key)
    local preferences = NotificationPreferences:LoadUserPreferences()

    -- Default to showing the notification if the preference is not set or malformed
    if preferences[key] == nil or type(preferences[key]) ~= "table" or preferences[key]["show"] == nil then
        preferences[key] = { show = true }
        JsonLayer:SaveJSONFile(self.NotificationPreferencesFilePath, preferences)
        return true
    end

    return preferences[key]["show"]
end
