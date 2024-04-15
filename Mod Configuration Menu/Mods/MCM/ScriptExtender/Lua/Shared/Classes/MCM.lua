---@class MCM: MetaClass
---@field mods table<string, table> A table containing settings data for each mod
MCM = _Class:Create("MCM", nil, {
    schemas = {},
    settings = {}
})

-- -- NOTE: When introducing new (breaking) versions of the config file, add a new function to parse the new version and update the version number in the config file
-- -- local versionHandlers = {
-- --   [1] = parseVersion1Config,
-- --   [2] = parseVersion2Config,
-- -- }

function MCM:LoadConfigs()
    self.schemas, self.settings = ModConfig:GetSettings()

    self:SetConfigValue("MyInt", 40)
end

--- Get the settings table for a mod
---@param modGUID? string The UUID of the mod. When not provided, the settings for the current mod are returned (ModuleUUID is used)
---@return table<string, table> The settings table for the mod
function MCM:GetModSettings(modGUID)
    if modGUID then
        return self.settings[modGUID]
    else
        return self.settings[ModuleUUID]
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
    if not modGUID then
        modGUID = ModuleUUID
    end
    local modSettingsTable = self:GetModSettings(modGUID)

    modSettingsTable[settingName] = value
    ModConfig:UpdateSettingsForMod(modGUID, modSettingsTable)
end

--- Reset a configuration setting to its default value
---@param settingName string The name of the setting
---@param modGUID? GUIDSTRING The UUID of the mod (optional)
function MCM:ResetConfigValue(settingName, modGUID)
    -- Implement logic to reset the setting to its default value
    -- Use the Config class to access the default value and update the current configuration
end
