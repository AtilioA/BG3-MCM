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


---@class ModConfig
---@field private mods table<string, table> A table of modGUIDs that has a table of schemas and settings for each mod
ModConfig = _Class:Create("ModConfig", nil, {
    mods = {}
})

--- SECTION: FILE HANDLING
--- Generates the full path to a settings file, starting from the Script Extender folder.
--- @param modGUID string The mod's UUID to get the path for.
--- @return string The full path to the settings file.
function ModConfig:GetModFolderPath(modGUID)
    local MCMPath = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    local modFolderName = Ext.Mod.GetMod(modGUID).Info.Directory
    return MCMPath .. '/' .. modFolderName
end

function ModConfig:GetConfigFilePath(modGUID)
    return self:GetModFolderPath(modGUID) .. "/settings.json"
end

function ModConfig:SaveSettingsForMod(modGUID)
    local configFilePath = self:GetConfigFilePath(modGUID)
    JsonLayer:SaveJSONConfig(configFilePath, self.mods[modGUID].settingsValues)
end

function ModConfig:SaveAllSettings()
    for modGUID, settingsTable in pairs(self.mods) do
        self:SaveSettingsForMod(modGUID)
    end
end

function ModConfig:UpdateAllSettingsForMod(modGUID, settings)
    self.mods[modGUID].settingsValues = settings
    -- TODO: Validate and sanitize data
    self:SaveSettingsForMod(modGUID)
    Ext.Net.BroadcastMessage("MCM", Ext.Json.Stringify({ modGUID = modGUID, settings = settings }))
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
    self:LoadSchemas()
    self:LoadSettings()

    self:SaveAllSettings()

    return self.mods
end

--- Load the settings for a mod from the settings file.
---@param modGUID string The UUID of the mod
---@param schema table The schema for the mod
function ModConfig:LoadSettingsForMod(modGUID, schema)
    local configFilePath = self:GetModFolderPath(modGUID) .. "/settings.json"
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
    MCMPrinter:PrintWarning(1, "Settings file not found for mod '%s', trying to save default settings to JSON file '%s'",
        Ext.Mod.GetMod(modGUID).Info.Name, configFilePath)
    JsonLayer:SaveJSONConfig(configFilePath, defaultSettingsJSON)
end

--- Add missing keys from the settings file based on the schema
--- @param schema Schema The schema to use for the settings
--- @param settings table The settings to update
function ModConfig:AddKeysMissingFromSchema(schema, settings)
    for _, section in ipairs(schema:GetSections()) do
        for _, setting in ipairs(section:GetSettings()) do
            if settings[setting:GetId()] == nil then
                settings[setting:GetId()] = setting:GetDefault()
            end
        end
    end
end

--- Clean up settings entries that are not present in the schema
---@param schema table The schema for the mod
---@param settings table The settings to clean up
function ModConfig:RemoveDeprecatedKeys(schema, settings)
    -- Create a set of valid setting names from the schema
    local validSettings = {}
    for _, section in ipairs(schema.Sections) do
        for _, setting in ipairs(section.Settings) do
            validSettings[setting.Name] = true
        end
    end

    -- Remove any settings that are not in the valid set
    for key in pairs(settings) do
        if not validSettings[key] then
            settings[key] = nil
        end
    end
end

--- !SECTION: SETTINGS HANDLING
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
    self.mods[modGUID].schemas = Schema:New(preprocessedData)

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
