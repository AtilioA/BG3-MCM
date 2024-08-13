MCMServer = {}

--- Loads the profile manager and the configurations for all mods.
---@return nil
function MCMServer:LoadConfigs()
    MCMAPI.mods = ModConfig:GetSettings()
    MCMAPI.profiles = ModConfig:GetProfiles()
    MCMTest(0, "Done loading MCM configs")
end

--- Set the value of a configuration setting
---@param settingId string The id of the setting
---@param value any The new value of the setting
---@param modGUID GUIDSTRING The UUID of the mod
function MCMServer:SetSettingValue(settingId, value, modGUID)
    local modSettingsTable = MCMAPI:GetAllModSettings(modGUID)

    local isValid = MCMAPI:IsSettingValueValid(settingId, value, modGUID)
    MCMDebug(2, "Setting value for " .. settingId .. " is valid? " .. tostring(isValid))
    if not isValid then
        MCMWarn(1, "Invalid value for setting '" .. settingId .. " (" .. tostring(value) .. "). Value will not be saved.")

        -- Notify the client with the current value of the setting, so it can update its UI
        Ext.Net.BroadcastMessage(Channels.MCM_SETTING_UPDATED, Ext.Json.Stringify({
            modGUID = modGUID,
            settingId = settingId,
            value = modSettingsTable[settingId]
        }))
        return
    end

    modSettingsTable[settingId] = value
    ModConfig:UpdateAllSettingsForMod(modGUID, modSettingsTable)

    -- This is kind of a hacky way to emit events to other servers
    Ext.Net.BroadcastMessage(Channels.MCM_RELAY_TO_SERVERS,
        Ext.Json.Stringify({ channel = Channels.MCM_SAVED_SETTING, payload = { modGUID = modGUID, settingId = settingId, value = value } }))

    -- Notify clients that the setting has been updated
    Ext.Net.BroadcastMessage(Channels.MCM_SETTING_UPDATED, Ext.Json.Stringify({
        modGUID = modGUID,
        settingId = settingId,
        value = value
    }))
end

---@param settingId string The id of the setting to reset
---@param modGUID? GUIDSTRING The UUID of the mod (optional)
---@param clientRequest? boolean Whether the request came from the client
function MCMServer:ResetSettingValue(settingId, modGUID, clientRequest)
    modGUID = modGUID or ModuleUUID

    local blueprint = MCMAPI:GetModBlueprint(modGUID)

    local defaultValue = blueprint:RetrieveDefaultValueForSetting(settingId)
    if defaultValue == nil then
        MCMWarn(0,
            "Setting '" .. settingId .. "' not found in the blueprint for mod '" .. modGUID .. "'. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
    else
        self:SetSettingValue(settingId, defaultValue, modGUID, clientRequest)
        Ext.Net.BroadcastMessage(Channels.MCM_SETTING_RESET, Ext.Json.Stringify({
            modGUID = modGUID,
            settingId = settingId,
            defaultValue = defaultValue
        }))
    end
end

--- Create a new MCM profile
---@param profileName string The name of the new profile
function MCMServer:CreateProfile(profileName)
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local success = ModConfig.profileManager:CreateProfile(profileName)

    if success then
        Ext.Net.BroadcastMessage(Channels.MCM_SERVER_CREATED_PROFILE, Ext.Json.Stringify({
            profileName = profileName,
            newSettings = ModConfig.mods
        }))

        -- REFACTOR: (USE MODEVENTS) Notify other servers about the new profile creation
        Ext.Net.BroadcastMessage(Channels.MCM_RELAY_TO_SERVERS, Ext.Json.Stringify({
            channel = Channels.MCM_SERVER_CREATED_PROFILE,
            payload = {
                profileName = profileName
            }
        }))
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
        Ext.Net.BroadcastMessage(Channels.MCM_SERVER_SET_PROFILE, Ext.Json.Stringify({
            profileName = profileName,
            newSettings = ModConfig.mods
        }))

        -- Notify other servers about the profile change
        Ext.Net.BroadcastMessage(Channels.MCM_RELAY_TO_SERVERS, Ext.Json.Stringify({
            channel = Channels.MCM_SERVER_SET_PROFILE,
            payload = {
                fromProfile = ModConfig:GetCurrentProfile(),
                toProfile = profileName
            }
        }))
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
        Ext.Net.BroadcastMessage(Channels.MCM_SERVER_DELETED_PROFILE, Ext.Json.Stringify({
            profileName = profileName,
            newSettings = ModConfig.mods
        }))

        -- Notify other servers about the profile deletion
        Ext.Net.BroadcastMessage(Channels.MCM_RELAY_TO_SERVERS, Ext.Json.Stringify({
            channel = Channels.MCM_SERVER_DELETED_PROFILE,
            payload = {
                profileName = profileName
            }
        }))
    end

    return success
end

function MCMServer:LoadAndSendSettings()
    MCMDebug(1, "Reloading MCM configs...")
    MCMAPI:LoadConfigs()

    Ext.Net.BroadcastMessage(Channels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT,
        Ext.Json.Stringify({ mods = MCMAPI.mods, profiles = MCMAPI.profiles }))
end

--- Reset all settings for a mod to their default values
---@param modGUID? GUIDSTRING The UUID of the mod. When not provided, the settings for the current mod are reset (ModuleUUID is used)
-- function MCMServer:ResetAllSettings(modGUID)
--     local modBlueprint = MCMAPI.blueprints[modGUID]
--     local defaultSettings = Blueprint:GetDefaultSettingsFromBlueprint(modBlueprint)

--     ModConfig:UpdateAllSettingsForMod(modGUID, defaultSettings)
--     Ext.Net.BroadcastMessage(Channels.MCM_RELAY_TO_SERVERS,
--         Ext.Json.Stringify({ channel = Channels.MCM_RESET_ALL_MOD_SETTINGS, payload = { modGUID = modGUID, settings = defaultSettings } }))
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
--     Ext.Net.BroadcastMessage(Channels.MCM_SERVER_SEND_PROFILES,
--         Ext.Json.Stringify({ profiles = ModConfig:GetProfiles() }))
--     return ModConfig:GetProfiles()
-- end

-- Get the current MCM profile's name
--@return string The name of the current profile
function MCMServer:GetCurrentProfile()
    Ext.Net.BroadcastMessage(Channels.MCM_SERVER_SEND_CURRENT_PROFILE,
        Ext.Json.Stringify({ profileName = ModConfig.profileManager:GetCurrentProfile() }))
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    return ModConfig.profileManager:GetCurrentProfile()
end

-- --- Check if a setting value is valid given the mod blueprint
-- ---@param settingId string The id of the setting
-- ---@param value any The value to check
-- ---@return boolean Whether the value is valid
-- function MCMServer:IsSettingValueValid(settingId, value, modGUID)
--     local blueprint = MCMAPI:GetModBlueprint(modGUID)
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
--             modGUID .. "'. Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
--         return false
--     end
-- end

-- --- Get the value of a configuration setting
-- ---@param settingId string The id of the setting
-- ---@param modGUID string The UUID of the mod that has the setting
-- ---@return any The value of the setting
-- function MCMServer:GetSettingValue(settingId, modGUID)
--     if not modGUID then
--         MCMWarn(0, "modGUID is nil. Cannot get setting value.")
--         return nil
--     end

--     local modSettingsTable = MCMAPI:GetAllModSettings(modGUID)
--     if not modSettingsTable then
--         MCMWarn(0, "Mod settings table not found for mod '" .. modGUID .. "'.")
--         return nil
--     end

--     if modSettingsTable[settingId] ~= nil then
--         return modSettingsTable[settingId]
--     end

--     -- No settingId
--     MCMAPI:HandleMissingSetting(settingId, modSettingsTable, modGUID)
--     return nil
-- end

return MCMServer
