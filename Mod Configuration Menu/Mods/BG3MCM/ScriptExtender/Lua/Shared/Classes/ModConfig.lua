---@class ModsConfig
---@field mods table<string, ModConfigData>

---@class ModConfigData
---@field schemas Schema[]
---@field settings table<string, any>

---@class ModConfig
---@field private mods ModsConfig A table of modGUIDs that has a table of schemas and settings for each mod
---@field private profiles ProfileManager A table of profile data
-- The ModConfig class orchestrates the management of mod configuration values within MCM.
-- It provides methods for loading settings, saving settings, updating settings, calling validation, and managing the overall configuration *state* of the mods.
-- It relies on helper classes such as the JsonLayer and ProfileManager to handle the details of working with JSON files and managing user profiles.
--
-- ModConfig is responsible for:
-- - Loading and managing the configuration data for each mod
-- - Handling the loading, saving, and updating of mod settings
-- - Interfacing with the ProfileManager to manage user profiles
-- - Submitting and loading mod schemas
-- - Ensuring the consistency and integrity of the mod settings
ModConfig = _Class:Create("ModConfig", nil, {
    mods = {},
    profiles = ProfileManager
})

-- -- NOTE: When introducing new (breaking) versions of the config file, add a new function to parse the new version and update the version number in the config file?
-- -- local versionHandlers = {
-- --   [1] = parseVersion1Config,
-- --   [2] = parseVersion2Config,
-- -- }

--- SECTION: FILE HANDLING
--- Generates the full path to a settings file, starting from the Script Extender folder.
--- @param modGUID GUIDSTRING The mod's UUID to get the path for.
--- @return string The full path to the settings file.
function ModConfig:GetModProfileSettingsPath(modGUID)
    local MCMPath = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    local profileName = self.profiles:GetCurrentProfile()
    local profilePath = MCMPath .. '/' .. "Profiles" .. '/' .. profileName

    local modFolderName = Ext.Mod.GetMod(modGUID).Info.Directory
    return profilePath .. '/' .. modFolderName
end

--- Generates the full path to a settings file, starting from the Script Extender folder.
--- @param modGUID GUIDSTRING The mod's UUID to get the path for.
function ModConfig:GetSettingsFilePath(modGUID)
    return self:GetModProfileSettingsPath(modGUID) .. "/settings.json"
end

-- TODO: as always, refactor this nuclear waste
--- Save the settings for a mod to the settings file with tab and section information.
--- @param modGUID GUIDSTRING The mod's UUID to save the settings for.
function ModConfig:SaveSettingsForMod(modGUID)
    local configFilePath = self:GetSettingsFilePath(modGUID)
    local schema = self.mods[modGUID].schemas
    local settings = self.mods[modGUID].settingsValues
    local updatedSettings = {}

    for _, tab in ipairs(schema:GetTabs()) do
        local tabId = tab.TabId
        if tabId then
            updatedSettings[tabId] = updatedSettings[tabId] or {}
            if tab.Settings then -- Check if tab has direct settings
                for _, setting in ipairs(tab.Settings) do
                    local settingId = setting.Id
                    if settingId then
                        local updatedSetting = settings[settingId]
                        if updatedSetting == nil then
                            updatedSetting = setting:GetDefault()
                        end
                        updatedSettings[tabId][settingId] = updatedSetting
                    end
                end
            end
            if tab.Sections then -- Check if tab has sections with settings
                for _, section in ipairs(tab.Sections) do
                    local sectionId = section.SectionId
                    if sectionId then
                        updatedSettings[tabId][sectionId] = updatedSettings[tabId][sectionId] or {}
                        for _, setting in ipairs(section.Settings) do
                            local settingId = setting.Id
                            if settingId then
                                local updatedSetting = settings[settingId]
                                if updatedSetting == nil then
                                    updatedSetting = setting:GetDefault()
                                end
                                updatedSettings[tabId][sectionId][settingId] = updatedSetting
                            end
                        end
                    end
                end
            end
        end
    end

    JsonLayer:SaveJSONConfig(configFilePath, updatedSettings)
end

--- Save the settings for all mods to the settings files.
function ModConfig:SaveAllSettings()
    for modGUID, _settingsTable in pairs(self.mods) do
        self:SaveSettingsForMod(modGUID)
    end
end

--- Update the settings for a mod and save them to the settings file.
function ModConfig:UpdateAllSettingsForMod(modGUID, settings)
    self.mods[modGUID].settingsValues = settings
    -- TODO: Validate and sanitize data
    self:SaveSettingsForMod(modGUID)
end

--- SECTION: MCM CONFIG/PROFILE HANDLING
---Loads the MCM configuration file from the specified file path, used to load the profiles.
---@param configFilePath string The file path of the MCM configuration file to load.
---@return table|nil data parsed MCM configuration data, or nil if the file could not be loaded or parsed.
function ModConfig:LoadMCMConfigFromFile(configFilePath)
    local configFileContent = Ext.IO.LoadFile(configFilePath)
    if not configFileContent or configFileContent == "" then
        MCMWarn(1, "MCM config file not found: " .. configFilePath .. ". Creating default config.")
        local defaultConfig = ProfileManager.DefaultConfig
        JsonLayer:SaveJSONConfig(configFilePath, defaultConfig)
        return defaultConfig
    end

    local success, data = pcall(Ext.Json.Parse, configFileContent)
    if not success then
        MCMWarn(0, "Failed to parse MCM config file: " .. configFilePath)
        return nil
    end

    return data
end

-- TODO: rename this 💀 we already have too much 'name clashing'
--- Load the MCM configuration file from the mod's directory.
function ModConfig:LoadMCMConfig()
    local mcmFolder = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    local configFilePath = mcmFolder .. '/' .. 'mcm_config.json'
    return self:LoadMCMConfigFromFile(configFilePath)
end

---Get the ProfileManager instance used by ModConfig
---@return ProfileManager self.profiles The ProfileManager instance
function ModConfig:GetProfiles()
    return self.profiles
end

-- TODO: Implement profile deletion

--- SECTION: SETTINGS HANDLING
--- Load the settings for each mod from the settings file.
function ModConfig:LoadSettings()
    for modGUID, settingsTable in pairs(self.mods) do
        self:LoadSettingsForMod(modGUID, self.mods[modGUID].schemas)
    end
end

--- Load the schema for each mod and try to load the settings from the settings file.
--- If the settings file does not exist, the default values from the schema are used and the settings file is created.
---@return table<string, table> self.mods The settings for each mod
function ModConfig:GetSettings()
    -- Load the base MCM configuration file, which contains the profiles
    local profiles = ProfileManager:Create(self:LoadMCMConfig())
    if not profiles then
        MCMWarn(0,
            "Failed to load profiles from MCM configuration file. Please contact " ..
            Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
        return {}
    end
    self.profiles = profiles

    -- Get settings for each mod given the profile
    self:LoadSchemas()
    DataPreprocessing:SanitizeSchemas(self.mods)
    self:LoadSettings()

    -- Save the sanitized and validated settings back to the JSON files
    self:SaveAllSettings()

    return self.mods
end

--- Load the settings for a mod from the settings file.
---@param modGUID string The UUID of the mod
---@param schema table The schema for the mod
function ModConfig:LoadSettingsForMod(modGUID, schema)
    local settingsFilePath = self:GetSettingsFilePath(modGUID)
    local config = JsonLayer:LoadJSONConfig(settingsFilePath)
    if config then
        local flattenedConfig = JsonLayer:FlattenSettingsJSON(config)
        self:HandleLoadedSettings(modGUID, schema, flattenedConfig, settingsFilePath)
    else
        self:HandleMissingSettings(modGUID, schema, settingsFilePath)
    end
end

--- Handle the loaded settings for a mod. If a setting is missing from the settings file, it is added with the default value from the schema.
---@param modGUID string The UUID of the mod
---@param schema table The schema for the mod
---@param config table The loaded settings config
---@param settingsFilePath string The file path of the settings.json file
function ModConfig:HandleLoadedSettings(modGUID, schema, config, settingsFilePath)
    MCMTest(1, "Loaded settings for mod: " .. Ext.Mod.GetMod(modGUID).Info.Name)
    -- Add new settings, remove deprecated settings, update JSON file
    self:AddKeysMissingFromSchema(schema, config)
    self:RemoveDeprecatedKeys(schema, config)

    config = DataPreprocessing:ValidateAndFixSettings(schema, config)
    JsonLayer:SaveJSONConfig(settingsFilePath, config)

    self.mods[modGUID].settingsValues = config

    MCMTest(1, Ext.Json.Stringify(self.mods[modGUID].settingsValues))
end

--- Handle the missing settings for a mod. If the settings file is missing, the default settings from the schema are saved to the file.
---@param modGUID string The UUID of the mod
---@param schema table The schema for the mod
---@param settingsFilePath string The file path of the settings.json file
function ModConfig:HandleMissingSettings(modGUID, schema, settingsFilePath)
    local defaultSettingsJSON = Schema:GetDefaultSettingsFromSchema(schema)
    self.mods[modGUID].settingsValues = defaultSettingsJSON
    MCMWarn(1, "Settings file not found for mod '%s', trying to save default settings to JSON file '%s'",
        Ext.Mod.GetMod(modGUID).Info.Name, settingsFilePath)
    JsonLayer:SaveJSONConfig(settingsFilePath, defaultSettingsJSON)
end

--- TODO: modularize after 'final' schema structure is decided
--- Add missing keys from the settings file based on the schema
--- @param schema Schema The schema to use for the settings
--- @param settings SchemaSetting The settings to update
function ModConfig:AddKeysMissingFromSchema(schema, settings)
    local schemaSettings = schema:GetSettings()
    local schemaTabs = schema:GetTabs()

    if schemaSettings then
        for _, setting in ipairs(schemaSettings) do
            if settings[setting:GetId()] == nil then
                settings[setting:GetId()] = setting:GetDefault()
            end
        end
    end

    if schemaTabs then
        for _, tab in ipairs(schemaTabs) do
            local tabSections = tab.Sections
            local tabSettings = tab:GetSettings()

            if tabSettings then
                for _, setting in ipairs(tabSettings) do
                    if settings[setting:GetId()] == nil then
                        settings[setting:GetId()] = setting:GetDefault()
                    end
                end
            elseif tabSections then
                for _, section in ipairs(tabSections) do
                    for _, setting in ipairs(section.Settings) do
                        if settings[setting:GetId()] == nil then
                            settings[setting:GetId()] = setting:GetDefault()
                        end
                    end
                end
            end
        end
    end
end

--- TODO: modularize after 'final' schema structure is decided
--- Clean up settings entries that are not present in the schema
---@param schema Schema The schema for the mod
---@param settings SchemaSetting The settings to clean up
function ModConfig:RemoveDeprecatedKeys(schema, settings)
    -- Create a set of valid setting names from the schema
    local validSettings = {}

    local schemaSettings = schema:GetSettings()
    local schemaTabs = schema:GetTabs()

    if schemaSettings then
        for _, setting in ipairs(schemaSettings) do
            validSettings[setting:GetId()] = true
        end
    end

    if schemaTabs then
        for _, tab in ipairs(schemaTabs) do
            local tabSections = tab.Sections
            local tabSettings = tab:GetSettings()

            if #tabSettings > 0 then
                for _, setting in ipairs(tabSettings) do
                    validSettings[setting:GetId()] = true
                end
            elseif #tabSections > 0 then
                for _, section in ipairs(tab.Sections) do
                    for _, setting in ipairs(section.Settings) do
                        validSettings[setting:GetId()] = true
                    end
                end
            end
        end
    end

    -- Remove any settings that are not in the valid set
    for key in pairs(settings) do
        if not validSettings[key] then
            settings[key] = nil
        end
    end
end

--- SECTION: SCHEMA HANDLING
--- Submit the schema data to the ModConfig instance
---@param data table The mod schema data to submit
---@param modGUID string The UUID of the mod that the schema data belongs to
---@return nil
function ModConfig:SubmitSchema(data, modGUID)
    local preprocessedData = DataPreprocessing:PreprocessData(data, modGUID)
    if not preprocessedData then
        MCMWarn(0,
            "Failed to preprocess data for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return
    end

    self.mods[modGUID] = {
        schemas = Schema:New(preprocessedData),
    }

    MCMTest(1, "Schema for mod " .. Ext.Mod.GetMod(modGUID).Info.Name .. " is ready to be used.")
end

--- Load settings files for each mod in the load order, if they exist. The settings file should be named "MCM_schema.json" and be located in the mod's directory, alongside the mod's meta.lsx file.
--- If the file is found, the data is submitted to the ModConfig instance.
--- If the file is not found, a warning is logged. If the file is found but cannot be parsed, an error is logged.
---@return nil
function ModConfig:LoadSchemas()
    for _, uuid in pairs(Ext.Mod.GetLoadOrder()) do
        self:LoadSchemaForMod(uuid)
    end
end

--- Load the schema for a mod and submit it to the ModConfig instance.
---@param uuid string The UUID of the mod to load the schema for
---@return nil
function ModConfig:LoadSchemaForMod(uuid)
    local modData = Ext.Mod.GetMod(uuid)
    MCMDebug(3, "Checking mod: " .. modData.Info.Name)

    local status, err = pcall(function()
        local data = JsonLayer:LoadConfigForMod(modData)
        if data then
            self:SubmitSchema(data, modData.Info.ModuleUUID)
        end
    end)

    if not status then
        self:HandleLoadSchemaError(modData, err)
    end
end

--- Handle errors that occur when loading a schema for a mod.
---@param modData table The mod data for the mod that the schema was being loaded for
---@param err table The error that occurred when loading the schema (thrown by JsonLayer)
function ModConfig:HandleLoadSchemaError(modData, err)
    if not err then
        MCMWarn(0, "An unexpected error occurred for mod: " .. modData.Info.Name .. ". Please contact " ..
            Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
        return
    end

    if err.code == "JSONParseError" then
        MCMWarn(0, err.message)
    elseif err.code == "FileNotFoundError" then
        MCMWarn(3, err.message)
    else
        -- Handle other unexpected errors (which ones lol)
        MCMWarn(0, "An unexpected error occurred for mod: " .. modData.Info.Name .. ". Please contact " ..
            Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
    end
end
