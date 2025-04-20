---@class MCMServer
MCMServer = _Class:Create("MCMServer", nil, {})

--- Loads the profile manager and the configurations for all mods.
---@return nil
function MCMServer:LoadConfigs()
    MCMAPI.mods = ModConfig:GetSettings()
    MCMAPI.profiles = ModConfig:GetProfiles()
    MCMSuccess(0, "Finished loading MCM blueprints")
end

--- Get the settings table for a mod
---@param modUUID GUIDSTRING The UUID of the mod to retrieve settings from
---@return table<string, table> - The settings table for the mod
function MCMServer:GetAllModSettings(modUUID)
    if not modUUID then
        MCMWarn(0, "modUUID is nil. Cannot get mod settings.")
        return {}
    end

    local mod = MCMAPI.mods[modUUID]
    if not mod then
        MCMWarn(0,
            "Mod " ..
            modUUID ..
            " was not found by MCM.\nDouble check your blueprint filename, directory, and whether it's well-defined. Please contact " ..
            Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
        return {}
    end

    return mod.settingsValues
end

--- Set the value of a configuration setting
---@param settingId string The id of the setting
---@param value any The new value of the setting
---@param modUUID GUIDSTRING The UUID of the mod
function MCMServer:SetSettingValue(settingId, value, modUUID)
    local modSettingsTable = MCMAPI:GetAllModSettings(modUUID)
    local oldValue = modSettingsTable[settingId]

    local isValid = MCMAPI:IsSettingValueValid(settingId, value, modUUID)
    MCMDebug(2, "Setting value for " .. settingId .. " is valid? " .. tostring(isValid))
    if not isValid then
        local errorMessage = "Invalid value for setting '" ..
            settingId .. " (" .. tostring(value) .. "). Value will not be saved."
        MCMWarn(1, errorMessage)

        -- Notify the client with the current value of the setting, so it can update its UI
        ModEventManager:Emit(EventChannels.MCM_SETTING_SAVED, {
            modUUID = modUUID,
            settingId = settingId,
            value = value,
            oldValue = value,
            error = errorMessage
        })
        return
    end

    modSettingsTable[settingId] = value
    ModConfig:UpdateAllSettingsForMod(modUUID, modSettingsTable)

    -- Notify MCM clients
    ModEventManager:Emit(EventChannels.MCM_INTERNAL_SETTING_SAVED, {
        modUUID = modUUID,
        settingId = settingId,
        value = value,
        oldValue = oldValue
    }, true)

    -- Notify other mods
    ModEventManager:Emit(EventChannels.MCM_SETTING_SAVED, {
        modUUID = modUUID,
        settingId = settingId,
        value = value,
        oldValue = oldValue
    })
end

---@param settingId string The id of the setting to reset
---@param modUUID? GUIDSTRING The UUID of the mod (optional)
function MCMServer:ResetSettingValue(settingId, modUUID)
    modUUID = modUUID or ModuleUUID

    local blueprint = MCMAPI:GetModBlueprint(modUUID)
    if not blueprint then
        MCMWarn(0, "Blueprint not found for mod '" .. modUUID .. "'. Please contact " ..
            Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
        return
    end

    local defaultValue = blueprint:RetrieveDefaultValueForSetting(settingId)
    if defaultValue == nil then
        MCMWarn(0,
            "Default value for setting '" ..
            settingId .. "' not found in the blueprint for mod '" .. modUUID .. "'. Please contact " ..
            Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
    else
        self:SetSettingValue(settingId, defaultValue, modUUID)
        ModEventManager:Emit(EventChannels.MCM_SETTING_RESET, {
            modUUID = modUUID,
            settingId = settingId,
            defaultValue = defaultValue
        }, true)
    end
end

--- Create a new MCM profile
---@param profileName string The name of the new profile
function MCMServer:CreateProfile(profileName)
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local success = ModConfig.profileManager:CreateProfile(profileName)

    if success then
        ModEventManager:Emit(EventChannels.MCM_PROFILE_CREATED, {
            profileName = profileName,
            newSettings = ModConfig.mods
        })

        ModEventManager:Emit(EventChannels.MCM_PROFILE_CREATED, {
            profileName = profileName
        })
    end

    self:SetProfile(profileName)

    return success
end

--- Set the current MCM profile to the specified profile. This will also update the settings to reflect the new profile settings. If the profile does not exist, it will be created.
---@param profileName string The name of the profile to set as the current profile
---@return boolean success Whether the profile was successfully set
function MCMServer:SetProfile(profileName)
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local success = ModConfig.profileManager:SetCurrentProfile(profileName)

    if success then
        ModEventManager:Emit(EventChannels.MCM_PROFILE_ACTIVATED, {
            profileName = profileName,
            newSettings = ModConfig.mods
        })

        -- Notify other servers about the profile change
        ModEventManager:Emit(EventChannels.MCM_PROFILE_ACTIVATED, {
            fromProfile = ModConfig.profileManager:GetCurrentProfile(),
            toProfile = profileName
        })
    end

    return success
end

--- Delete a profile from the MCM
---@param profileName string The name of the profile to delete
---@return boolean success Whether the profile was successfully deleted
function MCMServer:DeleteProfile(profileName)
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local success = ModConfig.profileManager:DeleteProfile(profileName)

    if success then
        ModEventManager:Emit(EventChannels.MCM_PROFILE_DELETED, {
            profileName = profileName,
            newSettings = ModConfig.mods
        })

        -- Notify other servers about the profile deletion
        ModEventManager:Emit(EventChannels.MCM_PROFILE_DELETED, {
            profileName = profileName
        })
    end

    return success
end

function MCMServer:LoadAndSendSettings()
    MCMDebug(1, "Reloading MCM configs...")
    MCMAPI:LoadConfigs()

    Ext.Net.BroadcastMessage(NetChannels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT, Ext.Json.Stringify({
        mods = MCMAPI.mods,
        profiles = MCMAPI.profiles
    }))
end

--- Load configs and send to a specific user (for new clients)
---@param userID integer The ID of the user to send settings to
function MCMServer:LoadAndSendSettingsToUser(userID)
    MCMDebug(1, "Sending MCM configs to user: " .. userID)
    MCMAPI:LoadConfigs()
    Ext.Net.PostMessageToClient(userID, NetChannels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT,
        Ext.Json.Stringify({ mods = MCMAPI.mods, profiles = MCMAPI.profiles }))
end

--- Reset all settings for a mod to their default values
-- -@param modUUID? GUIDSTRING The UUID of the mod. When not provided, the settings for the current mod are reset (ModuleUUID is used)
-- function MCMServer:ResetAllSettings(modUUID)
--     local modBlueprint = MCMAPI.blueprints[modUUID]
--     local defaultSettings = Blueprint:GetDefaultSettingsFromBlueprint(modBlueprint)

--     ModConfig:UpdateAllSettingsForMod(modUUID, defaultSettings)
--     Ext.Net.BroadcastMessage(NetChannels.MCM_RELAY_TO_SERVERS,
--         Ext.Json.Stringify({ channel = EventChannels.MCM_ALL_MOD_SETTINGS_RESET, payload = { modUUID = modUUID, settings = defaultSettings } }))
-- end

-- UNUSED since profile management currently calls shared code
-- --- Message handler for when the (IMGUI) client requests a new profile to be created
-- Ext.RegisterNetListener("MCM_Client_Request_Create_Profile", function(_, payload)
--     local payload = Ext.Json.Parse(payload)
--     local newProfileName = payload.profileName

--     MCMDebug(1, "Will create a new profile named " .. newProfileName)
--     MCMAPI:CreateProfile(newProfileName)
-- end)

-- --- Message handler for when the (IMGUI) client requests a profile to be deleted
-- Ext.RegisterNetListener("MCM_Client_Request_Delete_Profile", function(_, payload)
--     local payload = Ext.Json.Parse(payload)
--     local profileToDelete = payload.profileName

--     MCMDebug(1, "Will delete the profile named " .. profileToDelete)
--     MCMAPI:DeleteProfile(profileToDelete)
-- end)

--- Get the table of MCM profiles
---@return table<string, table> The table of profiles
-- function MCMServer:GetProfiles()
--     Ext.Net.BroadcastMessage(NetChannels.MCM_SERVER_SEND_PROFILES,
--         Ext.Json.Stringify({ profiles = ModConfig:GetProfiles() }))
--     return ModConfig:GetProfiles()
-- end

-- Get the current MCM profile's name
--@return string The name of the current profile
function MCMServer:GetCurrentProfile()
    Ext.Net.BroadcastMessage(NetChannels.MCM_SERVER_SEND_CURRENT_PROFILE,
        Ext.Json.Stringify({ profileName = ModConfig.profileManager:GetCurrentProfile() }))
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    return ModConfig.profileManager:GetCurrentProfile()
end

-- --- Check if a setting value is valid given the mod blueprint
-- ---@param settingId string The id of the setting
-- ---@param value any The value to check
-- ---@return boolean Whether the value is valid
-- function MCMServer:IsSettingValueValid(settingId, value, modUUID)
--     local blueprint = MCMAPI:GetModBlueprint(modUUID)
--     local setting = blueprint:GetAllSettings()[settingId]

--     if setting then
--         local isValid = DataPreprocessing:ValidateSetting(setting, value)
--         if not isValid then
--             MCMWarn(0,
--                 "Invalid value for setting '" .. settingId .. "' (" .. tostring(value) .. "). Value will not be saved.")
--         end
--         return isValid
--     else
--         MCMWarn(0,
--             "Setting '" ..
--             settingId ..
--             "' not found in the blueprint for mod '" ..
--             modUUID .. "'. Please contact " .. Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
--         return false
--     end
-- end

--- Get the value of a configuration setting
---@param settingId string The id of the setting
---@param modUUID string The UUID of the mod that has the setting
---@return any The value of the setting
function MCMServer:GetSettingValue(settingId, modUUID)
    if not modUUID then
        MCMWarn(0, "modUUID is nil. Cannot get setting value.")
        return nil
    end

    local modSettingsTable = MCMAPI:GetAllModSettings(modUUID)
    if not modSettingsTable then
        MCMWarn(0, "Mod settings table not found for mod '" .. modUUID .. "'.")
        return nil
    end

    if modSettingsTable[settingId] ~= nil then
        return modSettingsTable[settingId]
    end

    -- No settingId
    MCMAPI:HandleMissingSetting(settingId, modSettingsTable, modUUID)
    return nil
end

return MCMServer
