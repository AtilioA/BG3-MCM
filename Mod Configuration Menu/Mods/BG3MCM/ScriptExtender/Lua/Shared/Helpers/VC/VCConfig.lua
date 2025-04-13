--[[
    This code snippet is from Volition Cabinet, and was written entirely by Volitio.

    Handles loading, saving, and updating configuration settings for mods.
    Dependencies: Requires Ext.IO for file operations and Ext.Json for JSON parsing and stringification. Cannot use Printer since that one relies on this module.
    Usage: This module defines a Config helper class that is used to manage mod configurations. It supports loading from a JSON file, saving updates back to the file, and dynamically updating configuration settings based on in-game commands.

    MIT License

    Copyright (c) 2024 Volitio

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

---@class HelperConfig: nil
--- @field folderName string|nil The folder where the configuration files are located.
--- @field configFilePath string|nil The path to the configuration JSON file.
--- @field defaultConfig table The default configuration values for the mod, utilized when the configuration file is not found or when missing keys are detected.
--- @field currentConfig table The current configuration values after loading and potentially updating from a file.
--- @field onConfigReloaded table A list of callbacks to be executed when the configuration is reloaded.
VCConfig = _Class:Create("HelperConfig")

--- Sets basic configuration properties: folder name, config file path, and default config for the Config object
--- @param folderName string The name of the folder where the config file is stored.
--- @param configFilePath string The path to the configuration file relative to the folder.
--- @param defaultConfig table The default configuration values.
function VCConfig:SetConfig(folderName, configFilePath, defaultConfig)
    self.folderName = folderName or self.folderName
    self.configFilePath = configFilePath or self.configFilePath
    self.defaultConfig = defaultConfig or self.defaultConfig
end

--- Generates the full path to a configuration file, starting from the Script Extender folder.
--- @param filePath string The file name or relative path within the folderName.
--- @return string The full path to the config file.
function VCConfig:GetModFolderPath(filePath)
    return self.folderName .. '/' .. filePath
end

--- Loads a configuration from a file.
--- @param filePath string The file path to load the configuration from.
--- @return table|nil The loaded configuration table, or nil if loading failed.
function VCConfig:LoadConfig(filePath)
    local configFileContent = Ext.IO.LoadFile(self:GetModFolderPath(filePath))
    if not configFileContent or configFileContent == "" then
        VCPrint(0, "File not found: " .. filePath)
        return nil
    end

    -- VCPrint(1, "Loaded config file: " .. filePath)
    local success, parsed = pcall(Ext.Json.Parse, configFileContent)
    if not success then
        VCPrint(0, "Failed to parse config file: " .. filePath .. " - Regenerating default config.")
        self:SaveConfig(self.configFilePath, self.defaultConfig)
        return self.currentConfig
    end

    return parsed
end

--- Saves the given configuration to a file.
--- @param filePath string The file path to save the configuration to.
--- @param config table The configuration table to save.
function VCConfig:SaveConfig(filePath, config)
    local configFileContent = Ext.Json.Stringify(config)
    Ext.IO.SaveFile(self:GetModFolderPath(filePath), configFileContent)
end

--- Saves the current configuration to its file, using the object's values.
function VCConfig:SaveCurrentConfig()
    Ext.IO.SaveFile(self:GetModFolderPath(self.configFilePath),
        Ext.Json.Stringify(self.currentConfig))
end

--- Updates an existing configuration with values from the default configuration.
--- Recursively updates nested tables and ensures key/type consistency.
--- @param existingConfig table The existing configuration to be updated.
--- @param defaultConfig table The default configuration to update or check from.
--- @return boolean updated true if the configuration was updated, false otherwise.
function VCConfig:UpdateConfig(existingConfig, defaultConfig)
    local updated = false

    if self:AddMissingKeys(existingConfig, defaultConfig) then updated = true end
    if self:UpdateTypesAndValues(existingConfig, defaultConfig) then updated = true end
    if self:RecursiveUpdateForNestedTables(existingConfig, defaultConfig) then updated = true end
    -- if self:RemoveDeprecatedKeys(existingConfig, defaultConfig) then updated = true end

    return updated
end

function VCConfig:RecursiveUpdateForNestedTables(existingConfig, defaultConfig)
    local updated = false
    for key, newValue in pairs(defaultConfig) do
        local oldValue = existingConfig[key]

        -- Check if both the existing and new values are tables for recursive update
        if type(oldValue) == "table" and type(newValue) == "table" then
            -- Recursive call to handle nested tables
            if self:UpdateConfig(oldValue, newValue) then
                updated = true -- Mark as updated if any nested update was made
            end
        end
    end
    return updated
end

function VCConfig:AddMissingKeys(existingConfig, defaultConfig)
    for key, newValue in pairs(defaultConfig) do
        if existingConfig[key] == nil then
            existingConfig[key] = newValue
            VCPrint(0, "Added new config option: " .. tostring(key) .. " to " .. self.configFilePath)
            return true -- Early return indicating that an update was made
        end
    end
    return false -- No update was made
end

function VCConfig:UpdateTypesAndValues(existingConfig, defaultConfig)
    local updated = false
    for key, newValue in pairs(defaultConfig) do
        local oldValue = existingConfig[key]
        if type(oldValue) ~= type(newValue) then
            updated = true
            if type(newValue) == "table" then
                existingConfig[key] = { enabled = oldValue }
                for subKey, subValue in pairs(newValue) do
                    if existingConfig[key][subKey] == nil then
                        existingConfig[key][subKey] = subValue
                    end
                end
                VCPrint(0, "Updated config structure for: " .. tostring(key) .. " (" .. self.configFilePath .. ")")
            else
                existingConfig[key] = newValue
                VCPrint(0, "Updated config value for: " .. tostring(key) .. " (" .. self.configFilePath .. ")")
            end
        end
    end
    return updated
end

function VCConfig:RemoveDeprecatedKeys(existingConfig, defaultConfig)
    local updated = false
    for key, _ in pairs(existingConfig) do
        if defaultConfig[key] == nil and type(defaultConfig[key]) ~= "table" then
            existingConfig[key] = nil
            updated = true
            VCPrint(0, "Removed deprecated config option: " .. tostring(key) .. " (" .. self.configFilePath .. ")")
        end
    end
    return updated
end

--- Loads the configuration from the JSON file, updates it from the defaultConfig if necessary,
--- and saves back if changes are detected or if the file was not present.
--- @return table jsonConfig The loaded (and potentially updated) configuration.
function VCConfig:LoadJSONConfig()
    local jsonConfig = self:LoadConfig(self.configFilePath)
    if not jsonConfig then
        jsonConfig = self.defaultConfig
        self:SaveConfig(self.configFilePath, jsonConfig)
        VCPrint(0, "Created config file with default options." .. " (" .. self.configFilePath .. ")")
        return jsonConfig
    end

    local updated = self:UpdateConfig(jsonConfig, self.defaultConfig)
    if updated then
        self:SaveConfig(self.configFilePath, jsonConfig)
        VCPrint(0, "Config file updated with new options." .. " (" .. self.configFilePath .. ")")
    else
        -- Commented out because it's too verbose and we don't have access to a proper Printer object here
        -- VCPrint(1, "Config file loaded.")
    end

    return jsonConfig
end

--- Updates the currentConfig property with the configuration loaded from the file.
function VCConfig:UpdateCurrentConfig()
    self.currentConfig = self:LoadJSONConfig()
end

--- Accessor for the current configuration.
--- @return table The current configuration.
function VCConfig:getCfg()
    return self.currentConfig
end

--- Retrieves the current debug level from the configuration.
--- @return number The current debug level, with a default of 0 if not set.
function VCConfig:GetCurrentDebugLevel()
    if not self.currentConfig then
        return 0
    end

    return tonumber(self.currentConfig.DEBUG.level) or 0
end

function VCConfig:AddConfigReloadedCallback(callback)
    if self.onConfigReloaded == nil then
        self.onConfigReloaded = {}
    end

    table.insert(self.onConfigReloaded, callback)
end

function VCConfig:NotifyConfigReloaded()
    if self.onConfigReloaded == nil then
        return
    end

    for _, callback in ipairs(self.onConfigReloaded) do
        callback(self)
    end
end

function VCConfig:RegisterReloadConfigCommand(prefix)
    local commandName = prefix:lower() .. "_reload"
    Ext.RegisterConsoleCommand(commandName, function()
        self:UpdateCurrentConfig()
        self:NotifyConfigReloaded() -- Notify all subscribers that config has been reloaded.
    end)
end
