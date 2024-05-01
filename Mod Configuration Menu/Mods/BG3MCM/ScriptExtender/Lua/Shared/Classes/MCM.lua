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
    -- FIXME: profiles must be loaded after settings for some janky reason
end

--- Create a new MCM profile
---@param profileName string The name of the new profile
function MCM:CreateProfile(profileName)
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local success = ModConfig.profiles:CreateProfile(profileName)

    if success then
        -- Notify other servers about the new profile creation
        Ext.Net.BroadcastMessage("MCM_Relay_To_Servers", Ext.Json.Stringify({
            channel = "MCM_Profile_Created",
            payload = {
                profileName = profileName
            }
        }))
    end

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
    return ModConfig.profiles:GetCurrentProfile()
end

--- Set the current MCM profile to the specified profile. This will also update the settings to reflect the new profile settings. If the profile does not exist, it will be created.
---@param profileName string The name of the profile to set as the current profile
---@return boolean success Whether the profile was successfully set
function MCM:SetProfile(profileName)
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local currentProfile = self:GetCurrentProfile()
    local success = ModConfig.profiles:SetCurrentProfile(profileName)

    if success then
        -- Notify other servers about the profile change
        Ext.Net.BroadcastMessage("MCM_Relay_To_Servers", Ext.Json.Stringify({
            channel = "MCM_Profile_Changed",
            payload = {
                fromProfile = currentProfile,
                toProfile = profileName
            }
        }))
    end

    return success
end

--- Delete a profile from the MCM
---@param profileName string The name of the profile to delete
---@return boolean success Whether the profile was successfully deleted
function MCM:DeleteProfile(profileName)
    -- TODO: properly call ModConfig method instead of bastardizing the already bad OOP
    local success = ModConfig.profiles:DeleteProfile(profileName)

    if success then
        -- Notify other servers about the profile deletion
        Ext.Net.BroadcastMessage("MCM_Relay_To_Servers", Ext.Json.Stringify({
            channel = "MCM_Profile_Deleted",
            payload = {
                profileName = profileName
            }
        }))
    end

    return success
end

--- Get the settings table for a mod
---@param modGUID? string The UUID of the mod. When not provided, the settings for the current mod are returned (ModuleUUID is used)
---@return table<string, table> - The settings table for the mod
function MCM:GetModSettings(modGUID)
    if not modGUID then
        MCMWarn(0, "modGUID is nil. Cannot get mod settings. Please contact " ..
            Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
        return {}
    end

    local mod = self.mods[modGUID]
    if not mod then
        MCMWarn(1, "Mod " .. modGUID .. " not found in MCM settings")
        return {}
    end

    return mod.settingsValues
end

--- Get the Blueprint table for a mod
---@param modGUID? string The UUID of the mod. When not provided, the blueprint for the current mod is returned (ModuleUUID is used)
---@return Blueprint - The Blueprint for the mod
function MCM:GetModBlueprint(modGUID)
    if modGUID then
        return self.mods[modGUID].blueprints
    else
        return self.mods[ModuleUUID].blueprints
    end
end

--- Get the value of a configuration setting
---@param settingName string The name of the setting
---@param modGUID? GUIDSTRING The UUID of the mod (optional)
---@return any The value of the setting
function MCM:GetSettingValue(settingName, modGUID)
    local modSettingsTable = self:GetModSettings(modGUID)
    if modSettingsTable then
        return modSettingsTable[settingName]
    else
        return nil
    end
end

--- Set the value of a configuration setting
---@param settingId string The id of the setting
---@param value any The new value of the setting
---@param modGUID? GUIDSTRING The UUID of the mod (optional)
function MCM:SetSettingValue(settingId, value, modGUID, clientRequest)
    modGUID = modGUID or ModuleUUID

    local modSettingsTable = self:GetModSettings(modGUID)

    modSettingsTable[settingId] = value
    ModConfig:UpdateAllSettingsForMod(modGUID, modSettingsTable)

    -- This is kind of a hacky way to emit events to other servers
    -- TODO: check if there's a better way to do this; emit more events (e.g. profile changed)
    -- TODO: Remove settingName before release, I just don't want to break things right now lmao
    Ext.Net.BroadcastMessage("MCM_Relay_To_Servers",
        Ext.Json.Stringify({ channel = "MCM_Saved_Setting", payload = { modGUID = modGUID, settingId = settingId, settingName = settingId, value = value } }))

    if not clientRequest then
        -- Notify the client that the setting has been updated
        Ext.Net.BroadcastMessage("MCM_Setting_Updated", Ext.Json.Stringify({
            modGUID = modGUID,
            settingId = settingId,
            value = value
        }))
    end
end

---@param settingId string The id of the setting to reset
---@param modGUID? GUIDSTRING The UUID of the mod (optional)
---@param clientRequest? boolean Whether the request came from the client
function MCM:ResetSettingValue(settingId, modGUID, clientRequest)
    modGUID = modGUID or ModuleUUID

    local blueprint = self:GetModBlueprint(modGUID)

    local defaultValue = blueprint:RetrieveDefaultValueForSetting(settingId)
    if defaultValue == nil then
        MCMWarn(1,
            "Setting '" .. settingId .. "' not found in the blueprint for mod '" .. modGUID .. "'. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
    else
        self:SetSettingValue(settingId, defaultValue, modGUID, clientRequest)
        Ext.Net.BroadcastMessage("MCM_Setting_Reset", Ext.Json.Stringify({
            modGUID = modGUID,
            settingId = settingId,
            defaultValue = defaultValue
        }))
    end
end

--- Reset all settings for a mod to their default values
---@param modGUID? GUIDSTRING The UUID of the mod. When not provided, the settings for the current mod are reset (ModuleUUID is used)
function MCM:ResetAllSettings(modGUID)
    local modBlueprint = self.blueprints[modGUID]
    local defaultSettings = Blueprint:GetDefaultSettingsFromBlueprint(modBlueprint)

    ModConfig:UpdateAllSettingsForMod(modGUID, defaultSettings)
    Ext.Net.BroadcastMessage("MCM_Relay_To_Servers",
        Ext.Json.Stringify({ channel = "MCM_Server_Reset_All_Mod_Settings", payload = { modGUID = modGUID, settings = defaultSettings } }))
end

-- TODO: Separate these later into a different file?
function MCM:LoadAndSendSettings()
    MCMDebug(1, "Reloading MCM configs...")
    self:LoadConfigs()
    Ext.Net.BroadcastMessage("MCM_Server_Send_Configs_To_Client",
        Ext.Json.Stringify({ mods = MCMAPI.mods, profiles = MCMAPI.profiles }))
end

--- Message handler for when the (IMGUI) client requests the MCM settings to be loaded
Ext.RegisterNetListener("MCM_Client_Request_Configs", function(_)
    MCMDebug(1, "Received MCM settings request")
    MCMAPI:LoadAndSendSettings()
end)
Ext.RegisterConsoleCommand('mcm_reset', function() MCM:LoadAndSendSettings() end)

--- Message handler for when the (IMGUI) client requests a setting to be set
Ext.RegisterNetListener("MCM_Client_Request_Set_Setting_Value", function(_, payload)
    local payload = Ext.Json.Parse(payload)
    local settingId = payload.settingId
    local value = payload.value
    local modGUID = payload.modGUID

    if type(value) == "table" then
        MCMDebug(2, "Will set " .. settingId .. " to " .. Ext.Json.Stringify(value) .. " for mod " .. modGUID)
    else
        MCMDebug(1, "Will set " .. settingId .. " to " .. tostring(value) .. " for mod " .. modGUID)
    end
    MCMAPI:SetSettingValue(settingId, value, modGUID, true)
end)

--- Message handler for when the (IMGUI) client requests a setting to be reset
Ext.RegisterNetListener("MCM_Client_Request_Reset_Setting_Value", function(_, payload)
    local payload = Ext.Json.Parse(payload)
    local settingId = payload.settingId
    local modGUID = payload.modGUID

    MCMDebug(1, "Will reset " .. settingId .. " for mod " .. modGUID)
    MCMAPI:ResetSettingValue(settingId, modGUID, true)
end)

--- Message handler for when the (IMGUI) client requests a profile to be set
Ext.RegisterNetListener("MCM_Client_Request_Set_Profile", function(_, payload)
    local payload = Ext.Json.Parse(payload)
    local profileName = payload.profileName

    MCMDebug(1, "Will set profile to " .. profileName)
    MCMAPI:SetProfile(profileName)
end)
