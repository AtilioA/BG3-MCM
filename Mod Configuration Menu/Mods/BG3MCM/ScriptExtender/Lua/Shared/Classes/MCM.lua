---@class MCM: MetaClass
---@field private mods table<string, table> A table of modGUIDs that has a table of blueprints and settings for each mod
-- The MCM (Mod Configuration Menu) class is the main entry point for interacting with the Mod Configuration Menu system.
-- It acts as a high-level interface to the underlying ModConfig and ProfileManager classes, which handle the low-level details of loading, saving, and managing the mod configurations and user profiles, as well as JSON file handling from the JsonLayer class.
--
-- The MCM class is responsible for providing a consistent and user-friendly API for mod authors and the IMGUI client to interact with the Mod Configuration Menu system.
-- It provides methods for managing the configuration of mods, including:
-- - Loading the configurations for all mods
-- - Creating and managing user profiles
-- - Retrieving the settings and blueprints for individual mods
-- - Setting and getting the values of configuration settings
-- - Resetting settings to their default values
MCM = _Class:Create("MCM", nil, {
    mods = {},
    profiles = {},
})

--- Loads the profile manager and the configurations for all mods.
---@return nil
function MCM:LoadConfigs()
    self.mods = ModConfig:GetSettings()
    self.profiles = ModConfig:GetProfiles()
    MCMTest(0, "Done loading MCM configs")
end

--- Create a new MCM profile
---@param profileName string The name of the new profile
function MCM:CreateProfile(profileName)
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local success = ModConfig.profileManager:CreateProfile(profileName)

    if success then
        if Ext.IsServer() then
            Ext.Net.BroadcastMessage(Channels.MCM_SERVER_CREATED_PROFILE, Ext.Json.Stringify({
                profileName = profileName,
                newSettings = ModConfig.mods
            }))

            -- Notify other servers about the new profile creation
            Ext.Net.BroadcastMessage(Channels.MCM_RELAY_TO_SERVERS, Ext.Json.Stringify({
                channel = Channels.MCM_SERVER_CREATED_PROFILE,
                payload = {
                    profileName = profileName
                }
            }))
        end
    end

    self:SetProfile(profileName)

    return success
end

--- Get the table of MCM profiles
---@return table<string, table> The table of profiles
function MCM:GetProfiles()
    return ModConfig:GetProfiles()
end

--- Get the current MCM profile's name
---@return string The name of the current profile
function MCM:GetCurrentProfile()
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    return ModConfig.profileManager:GetCurrentProfile()
end

--- Set the current MCM profile to the specified profile. This will also update the settings to reflect the new profile settings. If the profile does not exist, it will be created.
---@param profileName string The name of the profile to set as the current profile
---@return boolean success Whether the profile was successfully set
function MCM:SetProfile(profileName)
    local currentProfile = self:GetCurrentProfile()
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local success = ModConfig.profileManager:SetCurrentProfile(profileName)
    MCMDebug(1, "Set profile to " .. profileName)

    if success then
        if Ext.IsServer() then
            Ext.Net.BroadcastMessage(Channels.MCM_SERVER_SET_PROFILE, Ext.Json.Stringify({
                profileName = profileName,
                newSettings = ModConfig.mods
            }))

            -- Notify other servers about the profile change
            Ext.Net.BroadcastMessage(Channels.MCM_RELAY_TO_SERVERS, Ext.Json.Stringify({
                channel = Channels.MCM_SERVER_SET_PROFILE,
                payload = {
                    fromProfile = currentProfile,
                    toProfile = profileName
                }
            }))
        end
    end

    return success
end

--- Delete a profile from the MCM
---@param profileName string The name of the profile to delete
---@return boolean success Whether the profile was successfully deleted
function MCM:DeleteProfile(profileName)
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local success = ModConfig.profileManager:DeleteProfile(profileName)

    if success then
        if Ext.IsServer() then
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
    end

    return success
end

--- Get the settings table for a mod
---@param modGUID GUIDSTRING The UUID of the mod to retrieve settings from
---@return table<string, table> - The settings table for the mod
function MCM:GetAllModSettings(modGUID)
    if not modGUID then
        MCMWarn(0, "modGUID is nil. Cannot get mod settings.")
        return {}
    end

    local mod = self.mods[modGUID]
    if not mod then
        MCMWarn(0,
            "Mod " ..
            modGUID ..
            " was not found by MCM. Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return {}
    end

    return mod.settingsValues
end

--- Get the Blueprint table for a mod
---@param modGUID GUIDSTRING The UUID of the mod.
---@return Blueprint - The Blueprint for the mod
function MCM:GetModBlueprint(modGUID)
    if modGUID then
        return self.mods[modGUID].blueprint
    end
end

--- Check if a setting value is valid given the mod blueprint
---@param settingId string The id of the setting
---@param value any The value to check
---@return boolean Whether the value is valid
function MCM:IsSettingValueValid(settingId, value, modGUID)
    local blueprint = self:GetModBlueprint(modGUID)
    local setting = blueprint:GetAllSettings()[settingId]

    if setting then
        local isValid = DataPreprocessing:ValidateSetting(setting, value)
        if not isValid then
            MCMWarn(0,
                "Invalid value for setting '" .. settingId .. "' (" .. tostring(value) .. "). Value will not be saved.")
        end
        return isValid
    else
        MCMWarn(0,
            "Setting '" ..
            settingId ..
            "' not found in the blueprint for mod '" ..
            modGUID .. "'. Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return false
    end
end

--- Get the value of a configuration setting
---@param settingId string The id of the setting
---@param modGUID string The UUID of the mod that has the setting
---@return any The value of the setting
function MCM:GetSettingValue(settingId, modGUID)
    if not modGUID then
        MCMWarn(0, "modGUID is nil. Cannot get setting value.")
        return nil
    end

    local modSettingsTable = self:GetAllModSettings(modGUID)
    if not modSettingsTable then
        MCMWarn(0, "Mod settings table not found for mod '" .. modGUID .. "'.")
        return nil
    end

    if modSettingsTable[settingId] ~= nil then
        return modSettingsTable[settingId]
    end

    -- No settingId
    self:HandleMissingSetting(settingId, modSettingsTable, modGUID)
    return nil
end

--- Get the names of all settings in the mod settings table
---@param modSettingsTable table The mod settings table
---@return string[] The names of all settings
function MCM:GetSettingsIDs(modSettingsTable)
    local settingIDs = {}
    for settingName, _ in pairs(modSettingsTable) do
        table.insert(settingIDs, settingName)
    end
    return settingIDs
end

-- TODO: add debouncing to this function
--- Handle the case when a setting is missing
---@param settingId string The id of the setting
---@param modSettingsTable table The mod settings table
---@param modGUID string The UUID of the mod
function MCM:HandleMissingSetting(settingId, modSettingsTable, modGUID)
    local modInfo = Ext.Mod.GetMod(modGUID).Info
    local closestMatch, distance = VCString:FindClosestMatch(settingId, self:GetSettingsIDs(modSettingsTable), false)
    if closestMatch and distance < 8 then
        MCMWarn(0,
            "Setting '" ..
            settingId ..
            "' not found for mod '" ..
            modInfo.Name ..
            "'. Did you mean '" .. closestMatch .. "'? Please contact " .. modInfo.Author .. " about this issue.")
    else
        MCMWarn(0,
            "Setting '" ..
            settingId ..
            "' not found for mod '" .. modInfo.Name .. "'. Please contact " .. modInfo.Author .. " about this issue.")
    end
end

--- Set the value of a configuration setting
---@param settingId string The id of the setting
---@param value any The new value of the setting
---@param modGUID GUIDSTRING The UUID of the mod
function MCM:SetSettingValue(settingId, value, modGUID, clientRequest)
    local modSettingsTable = self:GetAllModSettings(modGUID)

    local isValid = self:IsSettingValueValid(settingId, value, modGUID)
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

    -- if not clientRequest then
    -- Notify the client that the setting has been updated
    Ext.Net.BroadcastMessage(Channels.MCM_SETTING_UPDATED, Ext.Json.Stringify({
        modGUID = modGUID,
        settingId = settingId,
        value = value
    }))
    -- end
end

---@param settingId string The id of the setting to reset
---@param modGUID? GUIDSTRING The UUID of the mod (optional)
---@param clientRequest? boolean Whether the request came from the client
function MCM:ResetSettingValue(settingId, modGUID, clientRequest)
    modGUID = modGUID or ModuleUUID

    local blueprint = self:GetModBlueprint(modGUID)

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

--- Reset all settings for a mod to their default values
---@param modGUID? GUIDSTRING The UUID of the mod. When not provided, the settings for the current mod are reset (ModuleUUID is used)
-- function MCM:ResetAllSettings(modGUID)
--     local modBlueprint = self.blueprints[modGUID]
--     local defaultSettings = Blueprint:GetDefaultSettingsFromBlueprint(modBlueprint)

--     ModConfig:UpdateAllSettingsForMod(modGUID, defaultSettings)
--     Ext.Net.BroadcastMessage(Channels.MCM_RELAY_TO_SERVERS,
--         Ext.Json.Stringify({ channel = Channels.MCM_RESET_ALL_MOD_SETTINGS, payload = { modGUID = modGUID, settings = defaultSettings } }))
-- end

function MCM:LoadAndSendSettings()
    MCMDebug(1, "Reloading MCM configs...")
    self:LoadConfigs()
    -- TODO: untangle shared code from server/client
    if Ext.IsServer() then
        Ext.Net.BroadcastMessage(Channels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT,
            Ext.Json.Stringify({ mods = MCMAPI.mods, profiles = MCMAPI.profiles }))
    end
end

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
