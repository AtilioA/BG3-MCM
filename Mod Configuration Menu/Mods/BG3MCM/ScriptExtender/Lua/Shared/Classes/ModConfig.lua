---@class ModsConfig
---@field mods table<string, ModConfigData>

---@class ModConfigData
---@field blueprints Blueprint[]
---@field settings table<string, any>

---@class ModConfig
---@field private mods ModsConfig A table of modGUIDs that has a table of blueprints and settings for each mod
---@field private profiles ProfileManager A table of profile data
-- The ModConfig class orchestrates the management of mod configuration values within MCM.
-- It provides methods for loading settings, saving settings, updating settings, calling validation, and managing the overall configuration *state* of the mods.
-- It relies on helper classes such as the JsonLayer and ProfileManager to handle the details of working with JSON files and managing user profiles.
--
-- ModConfig is responsible for:
-- - Loading and managing the configuration data for each mod
-- - Handling the loading, saving, and updating of mod settings
-- - Interfacing with the ProfileManager to manage user profiles
-- - Submitting and loading mod blueprints
-- - Ensuring the consistency and integrity of the mod settings
ModConfig = _Class:Create("ModConfig", nil, {
    mods = {},
    profileManager = ProfileManager
})

ModConfig.MCMParamsFilename = "mcm_params.json"

-- -- NOTE: When introducing new (breaking) versions of the config file, add a new function to parse the new version and update the version number in the config file?
-- -- local versionHandlers = {
-- --   [1] = parseVersion1Config,
-- --   [2] = parseVersion2Config,
-- -- }

--- SECTION: FILE HANDLING
--- Generates the full path to a settings file, starting from the Script Extender folder.
--- @param modGUID GUIDSTRING The mod's UUID to get the path for.
function ModConfig:GetSettingsFilePath(modGUID)
    return self.profileManager:GetModProfileSettingsPath(modGUID) .. "/settings.json"
end

-- TODO: as always, refactor this nuclear waste
--- Save the settings for a mod to the settings file with tab and section information.
--- @param modGUID GUIDSTRING The mod's UUID to save the settings for.
function ModConfig:SaveSettingsForMod(modGUID)
    local configFilePath = self:GetSettingsFilePath(modGUID)
    local blueprint = self.mods[modGUID].blueprints
    local settings = self.mods[modGUID].settingsValues
    local updatedSettings = {}

    for _, tab in ipairs(blueprint:GetTabs()) do
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

    JsonLayer:SaveJSONFile(configFilePath, updatedSettings)
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

--- Load the MCM params file from the mod's SE directory.
function ModConfig:GetMCMParamsFilePath()
    local mcmFolder = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    return mcmFolder .. '/' .. self.MCMParamsFilename
end

---Loads the MCM params file from the specified file path, used to load the profiles.
---@param paramsFilepath string The file path of the MCM params file to load.
---@return table|nil data parsed MCM params data, or nil if the file could not be loaded or parsed.
function ModConfig:LoadMCMParams()
    local function loadMCMParamsFromFile(paramsFilepath)
        local configFileContent = Ext.IO.LoadFile(paramsFilepath)
        if not configFileContent or configFileContent == "" then
            MCMWarn(1, "MCM config file not found: " .. paramsFilepath .. ". Creating default config.")
            local defaultConfig = ProfileManager.DefaultConfig
            JsonLayer:SaveJSONFile(paramsFilepath, defaultConfig)
            return defaultConfig
        end

        local success, data = pcall(Ext.Json.Parse, configFileContent)
        if not success then
            MCMWarn(0, "Failed to parse MCM config file: " .. paramsFilepath)
            return nil
        end

        return data
    end

    local paramsFilepath = ModConfig:GetMCMParamsFilePath()
    return loadMCMParamsFromFile(paramsFilepath)
end

---Get the ProfileManager instance used by ModConfig
---@return ProfileManager self.profileManager The ProfileManager instance
function ModConfig:GetProfiles()
    return self.profileManager
end

--- SECTION: SETTINGS HANDLING
--- Load the settings for each mod from the settings file.
function ModConfig:LoadSettings()
    for modGUID, settingsTable in pairs(self.mods) do
        self:LoadSettingsForMod(modGUID, self.mods[modGUID].blueprints)
    end
end

--- Load the blueprint for each mod and try to load the settings from the settings file.
--- If the settings file does not exist, the default values from the blueprint are used and the settings file is created.
---@return table<string, table> self.mods The settings for each mod
function ModConfig:GetSettings()
    -- Load the base MCM configuration file, which contains the profiles
    local profileManager = ProfileManager:Create(self:LoadMCMParams())
    if not profileManager then
        MCMWarn(0,
            "Failed to load profiles from MCM configuration file. Please contact " ..
            Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
        return {}
    end
    self.profileManager = profileManager

    -- Get settings for each mod given the profile
    self:LoadBlueprints()
    BlueprintPreprocessing:SanitizeBlueprints(self.mods)
    self:LoadSettings()

    -- Save the sanitized and validated settings back to the JSON files
    self:SaveAllSettings()

    return self.mods
end

--- Load the settings for a mod from the settings file.
---@param modGUID string The UUID of the mod
---@param blueprint table The blueprint for the mod
function ModConfig:LoadSettingsForMod(modGUID, blueprint)
    local settingsFilePath = self:GetSettingsFilePath(modGUID)
    local config = JsonLayer:LoadJSONFile(settingsFilePath)
    if config then
        local flattenedConfig = JsonLayer:FlattenSettingsJSON(config)
        self:HandleLoadedSettings(modGUID, blueprint, flattenedConfig, settingsFilePath)
    else
        self:HandleMissingSettings(modGUID, blueprint, settingsFilePath)
    end
end

--- Handle the loaded settings for a mod. If a setting is missing from the settings file, it is added with the default value from the blueprint.
---@param modGUID string The UUID of the mod
---@param blueprint table The blueprint for the mod
---@param config table The table with all settings for the mod
---@param settingsFilePath string The file path of the settings.json file
function ModConfig:HandleLoadedSettings(modGUID, blueprint, config, settingsFilePath)
    MCMTest(1, "Loaded settings for mod: " .. Ext.Mod.GetMod(modGUID).Info.Name)
    -- Add new settings, remove deprecated settings, update JSON file
    self:AddKeysMissingFromBlueprint(blueprint, config)
    self:RemoveDeprecatedKeys(blueprint, config)

    config = DataPreprocessing:ValidateAndFixSettings(blueprint, config)
    JsonLayer:SaveJSONFile(settingsFilePath, config)

    self.mods[modGUID].settingsValues = config

    MCMTest(1, Ext.Json.Stringify(self.mods[modGUID].settingsValues))
    -- TODO: untangle this from shared client/server code
    -- Abhorrent hack to update the client's UI with the new settings. Since this is just a secondary feature, it is what it is for now. Sorry!
    if Ext.IsClient() and IMGUIAPI then
        for settingId, settingValue in pairs(self.mods[modGUID].settingsValues) do
            IMGUIAPI:UpdateSettingUIValue(modGUID, settingId, settingValue)
        end
    end
end

--- Handle the missing settings for a mod. If the settings file is missing, the default settings from the blueprint are saved to the file.
---@param modGUID string The UUID of the mod
---@param blueprint table The blueprint for the mod
---@param settingsFilePath string The file path of the settings.json file
function ModConfig:HandleMissingSettings(modGUID, blueprint, settingsFilePath)
    local defaultSettingsJSON = Blueprint:GetDefaultSettingsFromBlueprint(blueprint)
    self.mods[modGUID].settingsValues = defaultSettingsJSON
    MCMWarn(1, "Settings file not found for mod '%s', trying to save default settings to JSON file '%s'",
        Ext.Mod.GetMod(modGUID).Info.Name, settingsFilePath)
    JsonLayer:SaveJSONFile(settingsFilePath, defaultSettingsJSON)
end

--- TODO: modularize after 'final' blueprint structure is decided
--- Add missing keys from the settings file based on the blueprint
--- @param blueprint Blueprint The blueprint to use for the settings
--- @param settings BlueprintSetting The settings to update
function ModConfig:AddKeysMissingFromBlueprint(blueprint, settings)
    local BlueprintSettings = blueprint:GetSettings()
    local BlueprintTabs = blueprint:GetTabs()

    if BlueprintSettings then
        for _, setting in ipairs(BlueprintSettings) do
            if settings[setting:GetId()] == nil then
                settings[setting:GetId()] = setting:GetDefault()
            end
        end
    end

    if BlueprintTabs then
        for _, tab in ipairs(BlueprintTabs) do
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

--- TODO: modularize after 'final' blueprint structure is decided
--- Clean up settings entries that are not present in the blueprint
---@param blueprint Blueprint The blueprint for the mod
---@param settings BlueprintSetting The settings to clean up
function ModConfig:RemoveDeprecatedKeys(blueprint, settings)
    -- Create a set of valid setting names from the blueprint
    local validSettings = {}

    local BlueprintSettings = blueprint:GetSettings()
    local BlueprintTabs = blueprint:GetTabs()

    if BlueprintSettings then
        for _, setting in ipairs(BlueprintSettings) do
            validSettings[setting:GetId()] = true
        end
    end

    if BlueprintTabs then
        for _, tab in ipairs(BlueprintTabs) do
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

--- SECTION: BLUEPRINT HANDLING
--- Submit the blueprint data to the ModConfig instance
---@param data table The mod blueprint data to submit
---@param modGUID string The UUID of the mod that the blueprint data belongs to
---@return nil
function ModConfig:SubmitBlueprint(data, modGUID)
    local preprocessedData = DataPreprocessing:PreprocessData(data, modGUID)
    if not preprocessedData then
        MCMWarn(0,
            "Failed to preprocess data for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return
    end

    self.mods[modGUID] = {
        blueprints = Blueprint:New(preprocessedData),
    }

    MCMTest(1, "Blueprint for mod " .. Ext.Mod.GetMod(modGUID).Info.Name .. " is ready to be used.")
end

--- Load settings files for each mod in the load order, if they exist. The settings file should be named "MCM_blueprint.json" and be located in the mod's directory, alongside the mod's meta.lsx file.
--- If the file is found, the data is submitted to the ModConfig instance.
--- If the file is not found, a warning is logged. If the file is found but cannot be parsed, an error is logged.
---@return nil
function ModConfig:LoadBlueprints()
    for _, uuid in pairs(Ext.Mod.GetLoadOrder()) do
        self:LoadBlueprintForMod(uuid)
    end
end

--- Load the blueprint for a mod and submit it to the ModConfig instance.
---@param uuid string The UUID of the mod to load the blueprint for
---@return nil
function ModConfig:LoadBlueprintForMod(uuid)
    local modData = Ext.Mod.GetMod(uuid)
    MCMDebug(3, "Checking mod: " .. modData.Info.Name)

    local status, err = pcall(function()
        local data = JsonLayer:LoadBlueprintForMod(modData)
        if data then
            self:SubmitBlueprint(data, modData.Info.ModuleUUID)
        end
    end)

    if not status then
        self:HandleLoadBlueprintError(modData, err)
    end
end

--- Handle errors that occur when loading a blueprint for a mod.
---@param modData table The mod data for the mod that the blueprint was being loaded for
---@param err table The error that occurred when loading the blueprint (thrown by JsonLayer)
function ModConfig:HandleLoadBlueprintError(modData, err)
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
