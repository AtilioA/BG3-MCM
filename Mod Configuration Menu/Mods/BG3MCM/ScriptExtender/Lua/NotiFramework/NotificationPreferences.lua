---@class NotificationPreferences
---@field NotificationPreferencesFilePath string
NotificationPreferences = _Class:Create("NotificationPreferences", nil, {
    NotificationPreferencesFilePath = "notification_preferences.json"
})

function NotificationPreferences:LoadUserPreferences()
    local data = JsonLayer:LoadJSONFile(self.NotificationPreferencesFilePath)
    return data or {}
end

--- Stores the user preference for a notification
--- @param notificationKey string The unique identifier for the notification
--- @param modKey string|nil The key of the mod (optional)
--- @param preferenceValue table The preference value to store
local function storeUserPreference(notificationKey, modKey, preferenceValue)
    if notificationKey == nil or preferenceValue == nil then
        return
    end

    local preferences = NotificationPreferences:LoadUserPreferences()
    if preferences == nil then
        preferences = {}
    end

    if modKey then
        if not preferences[modKey] then
            preferences[modKey] = {}
        end
        -- Merge the existing values with the new preferenceValue
        preferences[modKey][notificationKey] = preferences[modKey][notificationKey] or {}
        for k, v in pairs(preferenceValue) do
            preferences[modKey][notificationKey][k] = v
        end
    else
        -- Merge the existing values with the new preferenceValue
        preferences[notificationKey] = preferences[notificationKey] or {}
        for k, v in pairs(preferenceValue) do
            preferences[notificationKey][k] = v
        end
    end

    JsonLayer:SaveJSONFile(NotificationPreferences.NotificationPreferencesFilePath, preferences)
end

local function getModName(modUUID)
    if modUUID then
        local mod = Ext.Mod.GetMod(modUUID)
        if mod and mod.Info then
            return mod.Info.Directory
        end
    end
    return 'Global'
end

--- Stores the user preference for a notification
--- @param modUUID string The UUID of the mod that owns the notification
--- @param key string The key of the notification
--- @return nil
function NotificationPreferences:StoreUserDontShowPreference(modUUID, key)
    if not key then
        MCMWarn(0, "No key provided to store user preference.")
        return
    end

    storeUserPreference(key, getModName(modUUID), { show = false })
end

--- Checks if a notification should be shown
--- @param key string The key of the notification
--- @param modUUID string The UUID of the mod that owns the notification
--- @return boolean
function NotificationPreferences:ShouldShowNotification(key, modUUID)
    local preferences = NotificationPreferences:LoadUserPreferences()

    -- Ensure modUUID is valid before accessing preferences
    if not modUUID then return true end

    local modName = getModName(modUUID)

    if preferences[modName] == nil then
        preferences[modName] = {}
    end

    -- Default to showing the notification if the preference is not set or malformed
    if preferences[modName][key] == nil or type(preferences[modName][key]) ~= "table" or preferences[modName][key]["show"] == nil then
        preferences[modName][key] = { show = true }
        JsonLayer:SaveJSONFile(self.NotificationPreferencesFilePath, preferences)
        return true
    end

    return preferences[modName][key]["show"]
end
