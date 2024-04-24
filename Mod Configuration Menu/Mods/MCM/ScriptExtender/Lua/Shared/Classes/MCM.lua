---@class MCM: MetaClass
---@field private mods table<string, table> A table of modGUIDs that has a table of schemas and settings for each mod
MCM = _Class:Create("MCM", nil, {
    mods = {},
    profiles = {},
})

-- -- NOTE: When introducing new (breaking) versions of the config file, add a new function to parse the new version and update the version number in the config file
-- -- local versionHandlers = {
-- --   [1] = parseVersion1Config,
-- --   [2] = parseVersion2Config,
-- -- }

function MCM:LoadConfigs()
    self.mods = ModConfig:GetSettings()
    self.profiles = ModConfig:GetProfiles()
    -- FIXME: profiles must be loaded after settings for some janky reason
    -- IMGUILayer:CreateModMenu(self.mods, self.profiles)
    Ext.Net.BroadcastMessage("MCM_Settings_To_Client", Ext.Json.Stringify({ mods = self.mods, profiles = self.profiles }))
end

--- Create a new MCM profile
---@param profileName string The name of the new profile
function MCM:CreateProfile(profileName)
    ModConfig:CreateProfile(profileName)
end

--- Get the table of MCM profiles
---@return table<string, table> The table of profiles
function MCM:GetProfiles()
    return ModConfig:GetProfiles()
end

--- Get the current MCM profile's name
---@return string The name of the current profile
function MCM:GetCurrentProfile()
    return ModConfig:GetCurrentProfile()
end

--- Set the current MCM profile to the specified profile. This will also update the settings to reflect the new profile settings. If the profile does not exist, it will be created.
---@param profileName string The name of the profile to set as the current profile
---@return boolean success Whether the profile was successfully set
function MCM:SetProfile(profileName)
    return ModConfig:SetCurrentProfile(profileName)
end

-- TODO: Implement profile deletion

--- Get the settings table for a mod
---@param modGUID? string The UUID of the mod. When not provided, the settings for the current mod are returned (ModuleUUID is used)
---@return table<string, table> self.mods[modGUID].settings settings table for the mod
function MCM:GetModSettings(modGUID)
    if modGUID then
        return self.mods[modGUID].settingsValues
    else
        return self.mods[ModuleUUID].settingsValues
    end
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
---@param settingName string The name of the setting
---@param value any The new value of the setting
---@param modGUID? GUIDSTRING The UUID of the mod (optional)
function MCM:SetConfigValue(settingName, value, modGUID)
    modGUID = modGUID or ModuleUUID

    local modSettingsTable = self:GetModSettings(modGUID)

    modSettingsTable[settingName] = value
    ModConfig:UpdateAllSettingsForMod(modGUID, modSettingsTable)
end

---@param settingName string The name of the setting to reset
---@param modGUID? GUIDSTRING The UUID of the mod (optional)
function MCM:ResetConfigValue(settingName, modGUID)
    modGUID = modGUID or ModuleUUID

    local schema = self:GetModSchema(modGUID)

    local defaultValue = schema:RetrieveDefaultValueForSetting(settingName)
    if defaultValue == nil then
        MCMWarn(1,
            "Setting '" .. settingName .. "' not found in the schema for mod '" .. modGUID .. "'. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
    else
        self:SetConfigValue(settingName, defaultValue, modGUID)
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
-- --- Reset all settings from a section to their default values
-- ---@param sectionName string The name of the section
-- ---@param modGUID? GUIDSTRING The UUID of the mod. When not provided, the settings for the current mod are reset (ModuleUUID is used)
-- function MCM:ResetSectionValues(sectionName, modGUID)
--     local modSchema = self.schemas[modGUID]
--     local defaultSettings = Schema:GetDefaultSettingsFromSchema(modSchema)
--     local modSettings = self.settings[modGUID]
-- end

function MCM:ResetCommand()
    MCMDebug(1, "Reloading MCM settings...")
    MCM:LoadConfigs()
    Ext.Net.BroadcastMessage("MCM_Settings_To_Client",
        Ext.Json.Stringify({ mods = self.mods, profiles = self.profiles }))
end

Ext.RegisterConsoleCommand('mcm_reset', function() MCM:ResetCommand() end)

Ext.Events.ResetCompleted:Subscribe(function()
    VCHelpers.Timer:OnTime(1000, function()
        MCM:ResetCommand()
    end)
end)

Ext.RegisterNetListener("MCM_SetConfigValue", function(_, payload)
    local payload = Ext.Json.Parse(payload)
    local settingId = payload.settingId
    local value = payload.value
    local modGUID = payload.modGUID

    MCMDebug(1, "Will set " .. settingId .. " to " .. tostring(value) .. " for mod " .. modGUID)
    MCM:SetConfigValue(settingId, value, modGUID)
end)
