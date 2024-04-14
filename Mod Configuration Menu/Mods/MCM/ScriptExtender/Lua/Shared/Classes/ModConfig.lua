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
ModConfig = _Class:Create("ModConfig", nil, {
    schemas = {},
    settingsValues = {},
    sectionsValues = {}
})

--- Generates the full path to a settings file, starting from the Script Extender folder.
--- @param modGUID string The mod's UUID to get the path for.
--- @return string The full path to the config file.
function ModConfig:GetModFolderPath(modGUID)
    local MCMPath = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    local modFolderName = Ext.Mod.GetMod(modGUID).Info.Directory
    return MCMPath .. '/' .. modFolderName
end

--- SECTION: SETTINGS HANDLING

--- Load the schema for each mod and try to load the settings from the settings file.
--- If the settings file does not exist, the default values from the schema are used and the settings file is created.
function ModConfig:LoadData()
    self:LoadSchemas()
    self:LoadSettings()
end

function ModConfig:LoadSettings()
    -- Read values from JSONs if they exist.
    -- If they don't, use the default values present in the schema.
    for modGUID, schema in pairs(self.schemas) do
        local configFilePath = self:GetModFolderPath(modGUID) .. "/settings.json"
        local config = JsonLayer:LoadJSONConfig(configFilePath)
        if config then
            -- Update the settings object with the values from the config file
        else
            -- Use the default values from the schema
            -- self.settings[modGUID] = self:GetDefaultSettingsFromSchema(schema)
            local defaultSettingsJSON = ModConfig:GetDefaultSettingsFromSchema(schema)
            _D("Trying to save default settings JSON: " .. configFilePath)
            JsonLayer:SaveJSONConfig(configFilePath, defaultSettingsJSON)
        end
    end
end

--- Produce a table with all settings for a mod and their default values as values. The sections will be used as keys, with a table of settings as values. Each setting will be a table with the setting name as key and the default value as value.
function ModConfig:GetDefaultSettingsFromSchema(schema)
    local settings = {}
    for _, section in ipairs(schema.Sections) do
        _D(section)
        settings[section.SectionName] = {}
        for _, setting in ipairs(section.Settings) do
            settings[section.SectionName][setting.Name] = setting.Default
        end
    end
    return settings
end

--- Maybe these two will not be needed
-- function ModConfig:UpdateSettingsFromSchema(schema, config)
--     local settings = {}
--     for _, section in ipairs(schema.Sections) do
--         for _, setting in ipairs(section.Settings) do
--             local settingName = setting.Name
--             if config[settingName] ~= nil then
--                 settings[settingName] = config[settingName]
--             else
--                 settings[settingName] = setting.Default
--             end
--         end
--     end
--     return settings
-- end

-- --- Produce a table with all sections for a mod and their settings as values
-- ---@param modGUID string The UUID of the mod to get the settings for
-- ---@return table<string, string[]> sectionSettings table with section names as keys and tables of setting names as values
-- function ModConfig:GetSettingsBySection(modGUID)
--     local sectionSettings = {}
--     local schema = self.schemas[modGUID]
--     if schema then
--         for _, section in ipairs(schema.Sections) do
--             sectionSettings[section.Name] = {}
--             for _, setting in ipairs(section.Settings) do
--                 table.insert(sectionSettings[section.Name], setting.Name)
--             end
--         end
--     end
--     return sectionSettings
-- end

--- !SECTION: SETTINGS HANDLING
--- SECTION: SCHEMA HANDLING

--- Submit the schema data to the ModConfig instance
---@param data table The mod schema data to submit
---@param modGUID string The UUID of the mod that the schema data belongs to
---@return nil
function ModConfig:SubmitSchema(data, modGUID)
    local preprocessedData = DataPreprocessing:PreprocessData(data, modGUID)
    if not preprocessedData then
        return
    end

    -- ISUtils:InitializeModVarsForMod(preprocessedData, modGUID)
    self.schemas[modGUID] = Schema:New(preprocessedData)

    MCMWarn(1, "Schema is ready for mod: " .. Ext.Mod.GetMod(modGUID).Info.Name)
end

--- Load config files for each mod in the load order, if they exist. The config file should be named "MCMFrameworkConfig.jsonc" and be located in the mod's directory, alongside the mod's meta.lsx file.
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
    _D(self:GetModFolderPath("15230bba-a3ab-4352-92f6-1c4c86d2a1e3"))
end
