-- --[[
--     This file has code adapted from sources originally licensed under the MIT License (JSON loading from CF). The terms of the MIT License are as follows:

--     MIT License

--     Copyright (c) 2023 BG3-Community-Library-Team

--     Permission is hereby granted, free of charge, to any person obtaining a copy
--     of this software and associated documentation files (the "Software"), to deal
--     in the Software without restriction, including without limitation the rights
--     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--     copies of the Software, and to permit persons to whom the Software is
--     furnished to do so, subject to the following conditions:

--     The above copyright notice and this permission notice shall be included in all
--     copies or substantial portions of the Software.

--     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--     SOFTWARE.
-- --]]

---@class ModsProfiles
---@field DefaultProfileName string
---@field SelectedProfile string
---@field Profiles table<string, string>

---@class ModsConfig
---@field mods table<string, ModConfigData>

---@class ModConfigData
---@field schemas Schema[]
---@field settings table<string, any>

---@class ModConfig
---@field private mods ModsConfig A table of modGUIDs that has a table of schemas and settings for each mod
---@field private profiles ModsProfiles A table of modGUIDs that has a table of schemas and settings for each mod
ModConfig = _Class:Create("ModConfig", nil, {
    mods = {},
    profiles = {}
})

--- SECTION: FILE HANDLING
--- Generates the full path to a settings file, starting from the Script Extender folder.
--- @param modGUID GUIDSTRING The mod's UUID to get the path for.
--- @return string The full path to the settings file.
function ModConfig:GetModFolderPath(modGUID)
    local MCMPath = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    local profileName = self:GetCurrentProfile()
    local profilePath = MCMPath .. '/' .. "Profiles" .. '/' .. profileName

    local modFolderName = Ext.Mod.GetMod(modGUID).Info.Directory
    return profilePath .. '/' .. modFolderName
end

--- Generates the full path to a settings file, starting from the Script Extender folder.
--- @param modGUID GUIDSTRING The mod's UUID to get the path for.
function ModConfig:GetConfigFilePath(modGUID)
    return self:GetModFolderPath(modGUID) .. "/settings.json"
end

--- Save the settings for a mod to the settings file.
--- @param modGUID GUIDSTRING The mod's UUID to save the settings for.
function ModConfig:SaveSettingsForMod(modGUID)
    local configFilePath = self:GetConfigFilePath(modGUID)
    JsonLayer:SaveJSONConfig(configFilePath, self.mods[modGUID].settingsValues)
end

--- Save the settings for all mods to the settings files.
function ModConfig:SaveAllSettings()
    for modGUID, settingsTable in pairs(self.mods) do
        self:SaveSettingsForMod(modGUID)
    end
end

--- Update the settings for a mod and save them to the settings file.
function ModConfig:UpdateAllSettingsForMod(modGUID, settings)
    self.mods[modGUID].settingsValues = settings
    -- TODO: Validate and sanitize data
    self:SaveSettingsForMod(modGUID)
end

--- SECTION: PROFILE HANDLING
-- Retrieve the currently selected profile from the MCM configuration
function ModConfig:GetCurrentProfile()
    -- Fallback to default if no profile data is found
    if not self.profiles or #self.profiles == 0 then
        return "Default"
    end

    if self.profiles.SelectedProfile then
        return self.profiles.SelectedProfile
    end

    return self.profiles.DefaultProfileName
end

-- Set the currently selected profile
function ModConfig:SetCurrentProfile(profileName)
    if not self.profiles then
        MCMWarn(1, "Profile feature is not properly configured in MCM.")
        return false
    end

    if not table.contains(self.profiles.Profiles, profileName) then
        MCMWarn(1,
            "Profile " ..
            profileName .. " does not exist. Available profiles: " .. self.profiles.Profiles)
        return false
    end

    self.profiles.Profiles.SelectedProfile = profileName
    return true
end

function ModConfig:LoadMCMConfig()
    local mcmFolder = ModConfig:GetModFolderPath(ModuleUUID)
    local configFilePath = mcmFolder .. '/' .. 'mcm_config.json'

    local configFileContent = Ext.IO.LoadFile(configFilePath)
    if not configFileContent or configFileContent == "" then
        MCMDebug(2, "MCM config file not found: " .. configFilePath)
        return nil
    end

    local success, data = pcall(Ext.Json.Parse, configFileContent)
    if not success then
        MCMWarn(0, "Failed to parse MCM config file: " .. configFilePath)
        return nil
    end

    self.profiles = data.Profiles
    return data
end

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
    self:LoadMCMConfig()

    -- Get settings for each mod given the profile
    self:LoadSchemas()
    DataPreprocessing:SanitizeSchemas(self.mods)
    self:LoadSettings()

    -- Save the sanitized and validated settings back to the JSON files
    self:SaveAllSettings()

    return self.mods
end

function ModConfig:GetProfiles()
    return self.profiles
end

--- Load the settings for a mod from the settings file.
---@param modGUID string The UUID of the mod
---@param schema table The schema for the mod
function ModConfig:LoadSettingsForMod(modGUID, schema)
    local configFilePath = self:GetConfigFilePath(modGUID)
    local config = JsonLayer:LoadJSONConfig(configFilePath)
    if config then
        self:HandleLoadedSettings(modGUID, schema, config, configFilePath)
    else
        self:HandleMissingSettings(modGUID, schema, configFilePath)
    end
end

--- Handle the loaded settings for a mod. If a setting is missing from the settings file, it is added with the default value from the schema.
---@param modGUID string The UUID of the mod
---@param schema table The schema for the mod
---@param config table The loaded settings config
---@param configFilePath string The file path of the settings.json file
function ModConfig:HandleLoadedSettings(modGUID, schema, config, configFilePath)
    MCMTest(1, "Loaded settings for mod: " .. Ext.Mod.GetMod(modGUID).Info.Name)

    -- Add new settings, remove deprecated settings, update JSON file
    self:AddKeysMissingFromSchema(schema, config)
    self:RemoveDeprecatedKeys(schema, config)

    config = DataPreprocessing:ValidateAndFixSettings(schema, config)
    JsonLayer:SaveJSONConfig(configFilePath, config)

    self.mods[modGUID].settingsValues = config

    MCMTest(1, Ext.Json.Stringify(self.mods[modGUID].settingsValues))
end

--- Handle the missing settings for a mod. If the settings file is missing, the default settings from the schema are saved to the file.
---@param modGUID string The UUID of the mod
---@param schema table The schema for the mod
---@param configFilePath string The file path of the settings.json file
function ModConfig:HandleMissingSettings(modGUID, schema, configFilePath)
    local defaultSettingsJSON = Schema:GetDefaultSettingsFromSchema(schema)
    self.mods[modGUID].settingsValues = defaultSettingsJSON
    MCMWarn(1, "Settings file not found for mod '%s', trying to save default settings to JSON file '%s'",
        Ext.Mod.GetMod(modGUID).Info.Name, configFilePath)
    JsonLayer:SaveJSONConfig(configFilePath, defaultSettingsJSON)
end

--- Add missing keys from the settings file based on the schema
--- @param schema Schema The schema to use for the settings
--- @param settings SchemaSetting The settings to update
function ModConfig:AddKeysMissingFromSchema(schema, settings)
    -- _D(schema)
    for _, section in ipairs(schema:GetSections()) do
        -- _D(section)
        for _, setting in ipairs(section:GetSettings()) do
            if settings[setting:GetId()] == nil then
                settings[setting:GetId()] = setting:GetDefault()
            end
        end
    end
end

--- Clean up settings entries that are not present in the schema
---@param schema Schema The schema for the mod
---@param settings SchemaSetting The settings to clean up
function ModConfig:RemoveDeprecatedKeys(schema, settings)
    -- Create a set of valid setting names from the schema
    local validSettings = {}
    for _, section in ipairs(schema:GetSections()) do
        for _, setting in ipairs(section:GetSettings()) do
            validSettings[setting:GetId()] = true
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

    -- ISUtils:InitializeModVarsForMod(preprocessedData, modGUID)
    self.mods[modGUID] = {
        schemas = Schema:New(preprocessedData),
    }

    MCMWarn(1, "Schema is ready for mod: " .. Ext.Mod.GetMod(modGUID).Info.Name)
end

--- Load settings files for each mod in the load order, if they exist. The settings file should be named "MCMFrameworkConfig.jsonc" and be located in the mod's directory, alongside the mod's meta.lsx file.
--- If the file is found, the data is submitted to the ModConfig instance.
--- If the file is not found, a warning is logged. If the file is found but cannot be parsed, an error is logged.
---@return nil
function ModConfig:LoadSchemas()
    -- Ensure ModVars table is initialized
    -- self:InitializeModVars()

    -- If only we had `continue` in Lua...
    for _, uuid in pairs(Ext.Mod.GetLoadOrder()) do
        local modData = Ext.Mod.GetMod(uuid)
        MCMDebug(3, "Checking mod: " .. modData.Info.Name)

        local filePath = JsonLayer.ConfigFilePathPatternJSON:format(modData.Info.Directory)
        local config = Ext.IO.LoadFile(filePath, "data")
        if config ~= nil and config ~= "" then
            MCMDebug(2, "Found config for mod: " .. Ext.Mod.GetMod(uuid).Info.Name)
            local data = JsonLayer:TryLoadConfig(config, uuid)
            -- _D(data)
            if data ~= nil and type(data) == "table" then
                self:SubmitSchema(data, uuid)
            else
                MCMWarn(0,
                    "Failed to load MCM config JSON file for mod: " ..
                    Ext.Mod.GetMod(uuid).Info.Name ..
                    ". Please contact " .. Ext.Mod.GetMod(uuid).Info.Author .. " about this issue.")
            end
        end
    end
end
