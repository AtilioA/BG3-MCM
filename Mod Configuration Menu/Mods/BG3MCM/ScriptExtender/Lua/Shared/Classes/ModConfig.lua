---@class ModsConfig
---@field mods table<string, ModConfigData>

---@class ModConfigData
---@field blueprints Blueprint[]
---@field settings table<string, any>

---@class ModConfig
---@field private mods ModsConfig A table of modUUIDs that has a table of blueprints and settings for each mod
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

--- Checks if a mod that has a blueprint has added MCM as a dependency. If it has not and MCM is not optional, a warning is logged.
function ModConfig:CheckMCMDependency(modUUID, blueprint)
    if modUUID == ModuleUUID then
        return
    end

    if blueprint:GetOptional() then
        return
    end

    local modData = Ext.Mod.GetMod(modUUID)
    local modDependencies = modData.Dependencies
    if not modDependencies then
        MCMWarn(0,
            string.format(
                "Mod '%s' does not have any dependencies. Please contact %s to add MCM as a dependency, or add `\"Optional\": true` to the blueprint.\nSee https://wiki.bg3.community/en/Tutorials/General/Basic/adding-mod-dependencies for more information.",
                modData.Info.Author))
        return
    end

    local hasMCMDependency = false
    for _, dependency in pairs(modDependencies) do
        if dependency.ModuleUUID == ModuleUUID then
            -- MCM is already a dependency, no need to log a warning
            hasMCMDependency = true
            return
        end
    end
    if not hasMCMDependency then
        MCMWarn(0,
            string.format(
                "Mod '%s' requires MCM but does not have MCM as a dependency. Please contact %s to add MCM as a dependency in the meta.lsx file, or add `\"Optional\": true` to the blueprint.\nSee https://wiki.bg3.community/en/Tutorials/General/Basic/adding-mod-dependencies for more information.", modData.Info.Name,
                modData.Info.Author))
    end
end

--- SECTION: FILE HANDLING
--- Generates the full path to a settings file, starting from the Script Extender folder.
--- @param modUUID GUIDSTRING The mod's UUID to get the path for.
function ModConfig:GetSettingsFilePath(modUUID)
    return self.profileManager:GetModProfileSettingsPath(modUUID) .. "/settings.json"
end

-- TODO: as always, refactor this nuclear waste (might only do when introducing recursive handling of tabs and sections)
--- Save the settings for a mod to the settings file with tab and section information.
--- @param modUUID GUIDSTRING The mod's UUID to save the settings for.
function ModConfig:SaveSettingsForMod(modUUID)
    local configFilePath = self:GetSettingsFilePath(modUUID)
    local blueprint = self.mods[modUUID].blueprint
    local settings = self.mods[modUUID].settingsValues
    local updatedSettings = {}

    for _, tab in ipairs(blueprint:GetTabs()) do
        local tabId = tab.TabId
        if tabId then
            updatedSettings[tabId] = updatedSettings[tabId] or {}
            if tab.Settings then -- Check if tab has direct settings
                for _, setting in ipairs(tab:GetSettings()) do
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
                        for _, setting in ipairs(section:GetSettings()) do
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
    for modUUID, _settingsTable in pairs(self.mods) do
        self:SaveSettingsForMod(modUUID)
    end
end

--- Update the settings for a mod and save them to the settings file.
function ModConfig:UpdateAllSettingsForMod(modUUID, settings)
    self.mods[modUUID].settingsValues = settings
    -- TODO: Validate and sanitize data
    self:SaveSettingsForMod(modUUID)
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
    for modUUID, settingsTable in pairs(self.mods) do
        self:LoadSettingsForMod(modUUID, self.mods[modUUID].blueprint)
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
---@param modUUID string The UUID of the mod
---@param blueprint table The blueprint for the mod
function ModConfig:LoadSettingsForMod(modUUID, blueprint)
    local settingsFilePath = self:GetSettingsFilePath(modUUID)
    local settings = JsonLayer:LoadJSONFile(settingsFilePath)
    if settings then
        local flattenedSettings = JsonLayer:FlattenSettingsJSON(settings)
        self:HandleLoadedSettings(modUUID, blueprint, flattenedSettings, settingsFilePath)
    else
        self:HandleMissingSettings(modUUID, blueprint, settingsFilePath)
    end
end

--- Handle the loaded settings for a mod. If a setting is missing from the settings file, it is added with the default value from the blueprint.
---@param modUUID string The UUID of the mod
---@param blueprint table The blueprint for the mod
---@param settings table The table with all settings for the mod
---@param settingsFilePath string The file path of the settings.json file
function ModConfig:HandleLoadedSettings(modUUID, blueprint, settings, settingsFilePath)
    MCMTest(1, "Loaded settings for mod: " .. Ext.Mod.GetMod(modUUID).Info.Name)
    -- Add new settings, remove deprecated settings, update JSON file
    self:AddKeysMissingFromBlueprint(blueprint, settings)
    self:RemoveDeprecatedKeys(blueprint, settings)

    settings = DataPreprocessing:ValidateAndFixSettings(blueprint, settings)
    JsonLayer:SaveJSONFile(settingsFilePath, settings)

    self.mods[modUUID].settingsValues = settings

    MCMTest(2, Ext.Json.Stringify(self.mods[modUUID].settingsValues))
    -- TODO: untangle this from shared client/server code
    -- Abhorrent hack to update the client's UI with the new settings. Since this is just a secondary feature, it is what it is for now. Sorry!
    -- if Ext.IsClient() and IMGUIAPI then
    --     for settingId, settingValue in pairs(self.mods[modUUID].settingsValues) do
    --         MCMClientState:SetClientStateValue(settingId, settingValue, modUUID)
    --     end
    -- end
end

--- Handle the missing settings for a mod. If the settings file is missing, the default settings from the blueprint are saved to the file.
---@param modUUID string The UUID of the mod
---@param blueprint table The blueprint for the mod
---@param settingsFilePath string The file path of the settings.json file
function ModConfig:HandleMissingSettings(modUUID, blueprint, settingsFilePath)
    local defaultSettingsJSON = Blueprint:GetDefaultSettingsFromBlueprint(blueprint)
    self.mods[modUUID].settingsValues = defaultSettingsJSON
    MCMWarn(1, "Settings file not found for mod '%s', trying to save default settings to JSON file '%s'",
        Ext.Mod.GetMod(modUUID).Info.Name, settingsFilePath)
    JsonLayer:SaveJSONFile(settingsFilePath, defaultSettingsJSON)
end

--- Add missing keys from the settings file based on the blueprint
--- @param blueprint Blueprint The blueprint to use for the settings
--- @param settings BlueprintSetting The settings to update
function ModConfig:AddKeysMissingFromBlueprint(blueprint, settings)
    local allSettings = blueprint:GetAllSettings()

    for _, setting in pairs(allSettings) do
        if settings[setting:GetId()] == nil then
            if settings[setting:GetOldId()] ~= nil and settings[setting:GetOldId()] ~= nil then
                settings[setting:GetId()] = settings[setting:GetOldId()]
            else
                settings[setting:GetId()] = setting:GetDefault()
            end
        end
    end
end

--- Clean up settings entries that are not present in the blueprint
---@param blueprint Blueprint The blueprint for the mod
---@param settings BlueprintSetting The settings to clean up
function ModConfig:RemoveDeprecatedKeys(blueprint, settings)
    -- Create a set of valid setting names from the blueprint
    local validSettings = {}

    local allSettings = blueprint:GetAllSettings()
    for id, _setting in pairs(allSettings) do
        validSettings[id] = true
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
---@param modUUID string The UUID of the mod that the blueprint data belongs to
---@return nil
function ModConfig:SubmitBlueprint(data, modUUID)
    local preprocessedData = DataPreprocessing:PreprocessData(data, modUUID)
    if not preprocessedData then
        MCMWarn(0,
            "Failed to preprocess data for mod: " ..
            Ext.Mod.GetMod(modUUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modUUID).Info.Author .. " about this issue.")
        return
    end

    self.mods[modUUID] = {
        blueprint = Blueprint:New(preprocessedData),
    }

    local modBlueprint = self.mods[modUUID].blueprint
    ModConfig:CheckMCMDependency(modUUID, modBlueprint)

    -- WIP/test
    -- xpcall(function() injectMCMToModTable(modUUID) end,
    --     function(err) MCMWarn(0, "Error injecting MCM to mod table: " .. tostring(err)) end)

    MCMTest(2, "Blueprint for mod '" .. Ext.Mod.GetMod(modUUID).Info.Name .. "' is ready to be used.")
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
        MCMWarn(0, "An unexpected blueprint error occurred for mod: " .. modData.Info.Name .. ". Please contact " ..
            Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.")
        return
    end

    if err.code == "JSONParseError" then
        MCMWarn(0, err.message)
    elseif err.code == "FileNotFoundError" then
        MCMWarn(3, err.message)
    else
        -- Handle other unexpected errors (which ones lol)
        MCMWarn(0, "An unexpected blueprint error occurred for mod: " .. modData.Info.Name .. ". Please contact " ..
            Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue:\n" .. err)
    end
end
