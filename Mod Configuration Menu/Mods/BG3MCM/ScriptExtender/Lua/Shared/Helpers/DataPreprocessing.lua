---@class HelperDataPreprocessing: Helper
DataPreprocessing = _Class:Create("HelperDataPreprocessing", Helper)

-- Convert string representations of booleans to actual boolean values in a table
local function convertStringBooleans(tbl)
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            convertStringBooleans(value)
        elseif value == "true" then
            tbl[key] = true
        elseif value == "false" then
            tbl[key] = false
        end
    end
end

--- TODO: validate if blueprint is correct, e.g. settings have unique IDs, etc.
--- Sanitizes blueprint data by removing elements without SchemaVersions and converting string booleans
---@param blueprint table The blueprint data to sanitize
---@param modGUID string The mod's unique identifier
function DataPreprocessing:SanitizeBlueprint(blueprint, modGUID)
    if not self:HasSchemaVersionsEntry(blueprint, modGUID) then
        return
    end
    convertStringBooleans(blueprint)
    return blueprint
end

--- Sanitize all blueprints for a given set of mods
---@param mods table<string, table> The mods data to sanitize
function DataPreprocessing:SanitizeBlueprints(mods)
    for modGUID, mcmTable in pairs(mods) do
        if not self:SanitizeBlueprint(mcmTable.blueprints, modGUID) then
            mods[modGUID] = nil
            MCMWarn(0,
                "Blueprint validation failed for mod: " ..
                Ext.Mod.GetMod(modGUID).Info.Name ..
                ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        end
    end
end

-- TODO: modularize this when the MCM schema has been defined
--- Validate the settings based on the blueprint and collect any invalid settings
---@param blueprint Blueprint The blueprint data
---@param settings BlueprintSetting The settings data
---@return boolean, string[] True if all settings are valid, and a list of invalid settings' IDs
function DataPreprocessing:ValidateSettings(blueprint, settings)
    local invalidSettings = {}

    local BlueprintTabs = blueprint:GetTabs()
    local BlueprintSettings = blueprint:GetSettings()

    if BlueprintTabs then
        for _, tab in ipairs(BlueprintTabs) do
            -- Check if the tab has sections
            if #tab:GetSections() > 0 then
                for _, section in ipairs(tab:GetSections()) do
                    for _, setting in ipairs(section:GetSettings()) do
                        local value = settings[setting:GetId()]
                        local validator = SettingValidators[setting:GetType()]
                        MCMDebug(2,
                            "Validating setting: " ..
                            setting:GetId() ..
                            " with value: " .. tostring(value) .. " using validator: " .. setting:GetType())
                        if validator and not validator(setting, value) then
                            table.insert(invalidSettings, setting:GetId())
                        end
                    end
                end
            else
                -- Validate settings directly in the tab
                for _, setting in ipairs(tab:GetSettings()) do
                    local value = settings[setting:GetId()]
                    local validator = SettingValidators[setting:GetType()]
                    MCMDebug(2,
                        "Validating setting: " ..
                        setting:GetId() ..
                        " with value: " .. tostring(value) .. " using validator: " .. setting:GetType())
                    if not validator or not validator(setting, value) then
                        table.insert(invalidSettings, setting:GetId())
                    end
                end
            end
        end
    end

    if BlueprintSettings then
        for _, setting in ipairs(BlueprintSettings) do
            local value = settings[setting:GetId()]
            local validator = SettingValidators[setting:GetType()]
            MCMDebug(2,
                "Validating setting: " ..
                setting:GetId() ..
                " with value: " .. tostring(value) .. " using validator: " .. setting:GetType())
            if validator and not validator(setting, value) then
                table.insert(invalidSettings, setting:GetId())
            end
        end
    end

    return #invalidSettings == 0, invalidSettings
end

-- TODO: modularize this when the MCM schema has been defined
--- Attempt to fix invalid settings by resetting them to default values
---@param blueprint Blueprint The blueprint data
---@param config table The configuration settings
---@return table The updated configuration settings
function DataPreprocessing:ValidateAndFixSettings(blueprint, config)
    local isValid, invalidSettings = DataPreprocessing:ValidateSettings(blueprint, config)
    if not isValid then
        for _, settingID in ipairs(invalidSettings) do
            local defaultValue = blueprint:RetrieveDefaultValueForSetting(settingID)
            MCMWarn(0,
                "Invalid value for setting: " ..
                settingID ..
                ". Resetting it to default value from the blueprint (" ..
                tostring(defaultValue) .. ").")
            config[settingID] = defaultValue
        end
    end
    return config
end

--- Check if the data table has a SchemaVersions table and validate its contents
---@param data table The item data to check
---@param modGUID string The UUID of the mod being processed
---@return boolean True if the data table has a SchemaVersions table and it is valid, false otherwise
function DataPreprocessing:HasSchemaVersionsEntry(data, modGUID)
    if not data.SchemaVersion then
        MCMDebug(2,
            "No 'SchemaVersion' section found in data for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name)
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
        MCMDebug(2,
            "No 'Sections' section found in data for mod: " .. Ext.Mod.GetMod(modGUID).Info.Name)
        return false
    end
    return true
end

-- TODO: modularize this when the schema has been defined
--- Preprocess the data and create BlueprintSetting instances for each setting found in the Tabs and Sections
---@param data table The item data to preprocess
---@param modGUID string The UUID of the mod that the item data belongs to
---@return table<string, BlueprintSetting>|nil The preprocessed data, or nil if the preprocessing failed
function DataPreprocessing:PreprocessData(data, modGUID)
    local preprocessedData = {}
    preprocessedData["SchemaVersion"] = data.SchemaVersion
    preprocessedData["ModName"] = data.ModName
    preprocessedData["Tabs"] = {}

    -- Iterate through each tab in the data
    for i, tab in ipairs(data.Tabs) do
        local tabData = BlueprintTab:New({
            TabId = tab.TabId,
            TabName = tab.TabName,
            Settings = {},
            Sections = {},
            Handles = tab.Handles or {}
        })
        -- Handle settings directly in tabs
        if tab.Settings then
            for j, setting in ipairs(tab.Settings) do
                local newSetting = BlueprintSetting:New({
                    Id = setting.Id,
                    Name = setting.Name,
                    Type = setting.Type,
                    Default = setting.Default,
                    Description = setting.Description,
                    Tooltip = setting.Tooltip,
                    Options = setting.Options or {},
                    Handles = setting.Handles or {}
                })
                table.insert(tabData.Settings, newSetting)
            end
        else
            MCMDebug(2,
                "No 'Settings' section found in tab: " ..
                tab.TabId .. " for mod: " .. Ext.Mod.GetMod(modGUID).Info.Name)
        end

        -- Handle sections containing settings
        if tab.Sections then
            for k, section in ipairs(tab.Sections) do
                local sectionData = BlueprintSection:New({
                    SectionId = section.SectionId,
                    SectionName = section.SectionName,
                    Settings = {},
                    Handles = section.Handles or {}
                })
                for l, setting in ipairs(section.Settings) do
                    local newSetting = BlueprintSetting:New({
                        Id = setting.Id,
                        Name = setting.Name,
                        Type = setting.Type,
                        Default = setting.Default,
                        Description = setting.Description,
                        Tooltip = setting.Tooltip,
                        Options = setting.Options or {},
                        Handles = setting.Handles or {}
                    })
                    table.insert(sectionData.Settings, newSetting)
                end
                table.insert(tabData.Sections, sectionData)
            end
        else
            MCMDebug(2,
                "No 'Sections' section found in tab: " .. tab.TabId .. " for mod: " .. Ext.Mod.GetMod(modGUID).Info.Name)
        end

        table.insert(preprocessedData.Tabs, tabData)
    end

    return preprocessedData
end
