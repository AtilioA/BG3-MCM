---@class MCM: MetaClass
---@field private schemas table<string, Schema> A table of schemas for each mod
---@field private settings table<string, table> A table of settings for each mod
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
end

--- Get the settings table for a mod
---@param modGUID? string The UUID of the mod. When not provided, the settings for the current mod are returned (ModuleUUID is used)
---@return table<string, table> self.settings settings table for the mod
function MCM:GetModSettings(modGUID)
    if modGUID then
        return self.settings[modGUID]
    else
        return self.settings[ModuleUUID]
    end
end

--- Get the Schema table for a mod
---@param modGUID? string The UUID of the mod. When not provided, the schema for the current mod is returned (ModuleUUID is used)
---@return Schema self.schema The Schema for the mod
function MCM:GetModSchema(modGUID)
    if modGUID then
        return self.schemas[modGUID]
    else
        return self.schemas[ModuleUUID]
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
    ModConfig:UpdateSettingsForMod(modGUID, modSettingsTable)
end

---@param settingName string The name of the setting to reset
---@param modGUID? GUIDSTRING The UUID of the mod (optional)
function MCM:ResetConfigValue(settingName, modGUID)
    modGUID = modGUID or ModuleUUID

    local schema = self:GetModSchema(modGUID)

    local defaultValue = schema:RetrieveDefaultValueForSetting(settingName)
    if defaultValue == nil then
        MCMWarn(1, "Setting '" .. settingName .. "' not found in the schema for mod '" .. modGUID .. "'.")
    else
        self:SetConfigValue(settingName, defaultValue, modGUID)
    end
end

--- Reset all settings for a mod to their default values
---@param modGUID? GUIDSTRING The UUID of the mod. When not provided, the settings for the current mod are reset (ModuleUUID is used)
function MCM:ResetAllSettings(modGUID)
    local modSchema = self.schemas[modGUID]
    local defaultSettings = Schema:GetDefaultSettingsFromSchema(modSchema)

    ModConfig:UpdateSettingsForMod(modGUID, defaultSettings)
end

-- --- Reset all settings from a section to their default values
-- ---@param sectionName string The name of the section
-- ---@param modGUID? GUIDSTRING The UUID of the mod. When not provided, the settings for the current mod are reset (ModuleUUID is used)
-- function MCM:ResetSectionValues(sectionName, modGUID)
--     local modSchema = self.schemas[modGUID]
--     local defaultSettings = Schema:GetDefaultSettingsFromSchema(modSchema)
--     local modSettings = self.settings[modGUID]
-- end
