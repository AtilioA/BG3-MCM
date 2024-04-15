---@class HelperDataPreprocessing: Helper
DataPreprocessing = _Class:Create("HelperDataPreprocessing", Helper)

local SettingValidators = {
    ["int"] = function(setting, value)
        return type(value) == "number" and math.floor(value) == value
    end,
    ["float"] = function(setting, value)
        return type(value) == "number"
    end,
    ["checkbox"] = function(setting, value)
        return type(value) == "boolean"
    end,
    ["text"] = function(setting, value)
        return type(value) == "string"
    end,
    ["enum"] = function(setting, value)
        local options = setting.Options.Choices
        return table.contains(options, value)
    end,
    ["slider"] = function(setting, value)
        local min, max = setting.Options.Min, setting.Options.Max
        return type(value) == "number" and value >= min and value <= max
    end,
    ["radio"] = function(setting, value)
        local options = setting.Options.Choices
        return table.contains(options, value)
    end,
    ["dict"] = function(setting, value)
        return type(value) == "table"
    end
}

-- Function to convert string booleans to actual booleans
local function convertStringBooleans(table)
    for key, value in pairs(table) do
        if type(value) == "table" then
            -- Recursively convert nested tables
            convertStringBooleans(value)
        elseif value == "true" then
            table[key] = true
        elseif value == "false" then
            table[key] = false
        end
    end
end

--- Remove elements in the table that do not have a SchemaVersions, etc.
---@param schema table The schema data to sanitize
function DataPreprocessing:SanitizeSchema(schema, modGUID)
    if not self:HasSchemaVersionsEntry(schema, modGUID) then
        return
    end

    if not self:HasSectionsEntry(schema, modGUID) then
        return
    end

    -- Turn string booleans into actual booleans
    convertStringBooleans(schema)

    return schema
end

--- Check if Schema data is well-formed
function DataPreprocessing:SanitizeSchemas(schemas)
    for modGUID, schema in pairs(schemas) do
        local self:SanitizeSchema(schema, modGUID)
    end
end

--- Check if Schema data has correct types and respect constraints
function DataPreprocessing:ValidateSchemas(schemas)
    self:SanitizeSchemas(schemas)
end

--- Check if settings data has correct types and respect constraints
function DataPreprocessing:ValidateSettings(schemas, settingsValues)
    for modGUID, schema in pairs(schemas) do
        local settings = settingsValues[modGUID]
        if settings then
            local self:ValidateSettings(schema, settings)
        end
    end
end

--- Validate the settings based on the schema
---@param schema table The schema data
---@param settings table The settings data
---@return boolean, string[] True if all settings are valid, and a list of invalid settings
function DataPreprocessing:ValidateSettings(schemas, settings)
    local invalidSettings = {}

    for _, section in ipairs(schema.Sections) do
        for _, setting in ipairs(section.Settings) do
            local value = settings[setting.Name]
            local validator = SettingValidators[setting.Type]
            if not validator(setting, value) then
                table.insert(invalidSettings, setting.Name)
            end
        end
    end

    return #invalidSettings == 0, invalidSettings
end


--- Check if the data table has a SchemaVersions table
---@param data table The item data to check
---@param modGUID string The UUID of the mod being processed
---@return boolean True if the data table has a SchemaVersions table, false otherwise
function DataPreprocessing:HasSchemaVersionsEntry(data, modGUID)
    if not data.SchemaVersion then
        MCMWarn(0,
            "No 'SchemaVersion' section found in data for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return false
    elseif type(data.SchemaVersion) ~= "number" then
        MCMWarn(0,
            "Invalid 'SchemaVersion' section (not a number) found in data for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return false
    end

    return true
end

--- Check if the data table has a Sections table
---@param data table The item data to check
---@param modGUID string The UUID of the mod being processed
---@return boolean True if the data table has a Sections table, false otherwise
function DataPreprocessing:HasSectionsEntry(data, modGUID)
    if not data.Sections then
        MCMWarn(0,
            "No 'Sections' section found in data for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return false
    end

    return true
end

--- Preprocess the data and create SchemaSetting instances
---@param data table The item data to preprocess
---@param modGUID string The UUID of the mod that the item data belongs to
---@return table<string, SchemaSetting>|nil The preprocessed data, or nil if the preprocessing failed
function DataPreprocessing:PreprocessData(data, modGUID)
    local preprocessedData = data
    for i, section in ipairs(data.Sections) do
        for j, setting in ipairs(section.Settings) do
            local setting = SchemaSetting:New({
                Name = setting.Name,
                Type = setting.Type,
                Default = setting.Default,
                Description = setting.Description,
                Section = setting.Section or "General",
                Options = setting.Options or {}
            })
            preprocessedData["Sections"][i]["Settings"][j] = setting
        end
    end

    return preprocessedData
end

--- PreprocessConfig is a wrapper function that calls the SanitizeData and ApplyDefaultValues functions.
---@param data table The item data to process
---@param modGUID string The GUID of the mod that the data belongs to
---@return table|nil The processed item data, or nil if the data could not be processed (e.g. if it failed sanitization due to invalid data)
function DataPreprocessing:PreprocessConfig(data, modGUID)
    local sanitizedData = self:SanitizeData(data, modGUID)
    if not sanitizedData then
        MCMWarn(0,
            "Failed to sanitize MCM config JSON data for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return
    end
    -- return sanitizedData

    -- return self:ApplyDefaultValues(data)
end
