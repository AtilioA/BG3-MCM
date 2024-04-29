---@class MCM: MetaClass
---@field private mods table<string, table> A table of modGUIDs that has a table of schemas and settings for each mod
-- The MCM (Mod Configuration Menu) class is the main entry point for interacting with the Mod Configuration Menu system.
-- It acts as a high-level interface to the underlying ModConfig and ProfileManager classes, which handle the low-level details of loading, saving, and managing the mod configurations and user profiles, as well as JSON file handling from the JsonLayer class.
--
-- The MCM class is responsible for providing a consistent and user-friendly API for mod authors and the IMGUI client to interact with the Mod Configuration Menu system.
-- It provides methods for managing the configuration of mods, including:
-- - Loading the configurations for all mods
-- - Creating and managing user profiles
-- - Retrieving the settings and schemas for individual mods
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
    ModConfig.profiles:CreateProfile(profileName)
end

--- Get the table of MCM profiles
---@return table<string, table> The table of profiles
function MCM:GetProfiles()
    return ModConfig:GetProfiles()
end

--- Get the current MCM profile's name
---@return string The name of the current profile
function MCM:GetCurrentProfile()
    return ModConfig.profiles:GetCurrentProfile()
end

--- Set the current MCM profile to the specified profile. This will also update the settings to reflect the new profile settings. If the profile does not exist, it will be created.
---@param profileName string The name of the profile to set as the current profile
---@return boolean success Whether the profile was successfully set
function MCM:SetProfile(profileName)
    return ModConfig.profiles:SetCurrentProfile(profileName)
end

--- Delete a profile from the MCM
---@param profileName string The name of the profile to delete
---@return boolean success Whether the profile was successfully deleted
function MCM:DeleteProfile(profileName)
    return ModConfig.profiles:DeleteProfile(profileName)
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

--- Get the Schema table for a mod
---@param modGUID? string The UUID of the mod. When not provided, the schema for the current mod is returned (ModuleUUID is used)
---@return Schema - The Schema for the mod
function MCM:GetModSchema(modGUID)
    if modGUID then
        return self.mods[modGUID].schemas
    else
        return self.mods[ModuleUUID].schemas
    end
end

--- Get the value of a configuration setting
---@param settingName string The name of the setting
---@param modGUID? GUIDSTRING The UUID of the mod (optional)
---@return any The value of the setting
function MCM:GetConfigValue(settingName, modGUID)
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
function MCM:SetConfigValue(settingId, value, modGUID, clientRequest)
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
function MCM:ResetConfigValue(settingId, modGUID, clientRequest)
    modGUID = modGUID or ModuleUUID

    local schema = self:GetModSchema(modGUID)

    local defaultValue = schema:RetrieveDefaultValueForSetting(settingId)
    if defaultValue == nil then
        MCMWarn(1,
            "Setting '" .. settingId .. "' not found in the schema for mod '" .. modGUID .. "'. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
    else
        self:SetConfigValue(settingId, defaultValue, modGUID, clientRequest)
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
    local modSchema = self.schemas[modGUID]
    local defaultSettings = Schema:GetDefaultSettingsFromSchema(modSchema)

    ModConfig:UpdateAllSettingsForMod(modGUID, defaultSettings)
end

-- TODO:
-- --- Reset all settings from a section to their default values?
-- ---@param sectionName string The name of the section
-- ---@param modGUID? GUIDSTRING The UUID of the mod. When not provided, the settings for the current mod are reset (ModuleUUID is used) (actually, this is not how it works :| )
-- function MCM:ResetSectionValues(sectionName, modGUID)
--     local modSchema = self.schemas[modGUID]
--     local defaultSettings = Schema:GetDefaultSettingsFromSchema(modSchema)
--     local modSettings = self.settings[modGUID]
-- end

--  Register a new tab to be displayed in the MCM
-- @param modGUID string The UUID of the mod
-- @param tabName string The name of the tab to display
-- @param tabCallback function A callback function that will be called to create the tab content
-- function MCM:RegisterModTab(modGUID, tabName, tabCallback)
--     -- Notify the IMGUILayer to add the new tab
--     Ext.Net.BroadcastMessage("MCM_Mod_Tab_Added", Ext.Json.Stringify({
--         modGUID = modGUID,
--         tabName = tabName,
--         tabCallback = tabCallback
--     }))
-- end

-- TODO: modularize these later
function MCM:LoadAndSendSettings()
    MCMDebug(1, "Reloading MCM settings...")
    MCM:LoadConfigs()
    Ext.Net.BroadcastMessage("MCM_Server_Send_Settings_To_Client",
        Ext.Json.Stringify({ mods = MCMAPI.mods, profiles = MCMAPI.profiles }))
end

--- Message handler for when the (IMGUI) client requests the MCM settings to be loaded
Ext.RegisterNetListener("MCM_Client_Request_Settings", function(_)
    MCMDebug(1, "Received MCM settings request")
    MCM:LoadAndSendSettings()
end)
Ext.RegisterConsoleCommand('mcm_reset', function() MCM:LoadAndSendSettings() end)

--- Message handler for when the (IMGUI) client requests a setting to be set
Ext.RegisterNetListener("MCM_Client_Request_Set_Setting_Value", function(_, payload)
    local payload = Ext.Json.Parse(payload)
    local settingId = payload.settingId
    local value = payload.value
    local modGUID = payload.modGUID

    MCMDebug(1, "Will set " .. settingId .. " to " .. tostring(value) .. " for mod " .. modGUID)
    MCM:SetConfigValue(settingId, value, modGUID, true)
end)

--- Message handler for when the (IMGUI) client requests a setting to be reset
Ext.RegisterNetListener("MCM_Client_Request_Reset_Setting_Value", function(_, payload)
    local payload = Ext.Json.Parse(payload)
    local settingId = payload.settingId
    local modGUID = payload.modGUID

    MCMDebug(1, "Will reset " .. settingId .. " for mod " .. modGUID)
    MCM:ResetConfigValue(settingId, modGUID, true)
end)
