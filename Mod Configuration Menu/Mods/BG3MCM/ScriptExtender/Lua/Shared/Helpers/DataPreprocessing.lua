---@class HelperDataPreprocessing: Helper
DataPreprocessing = _Class:Create("HelperDataPreprocessing", Helper)

--- Validate the structure of the blueprint data
---@param blueprint table The blueprint data to validate
---@param modGUID string The mod's unique identifier
---@return boolean True if the blueprint data is correct, false otherwise
function DataPreprocessing:HasIncorrectStructure(blueprint, modGUID)
    --- Check if blueprint has at least one tab
    local hasTabs = blueprint.Tabs and #blueprint.Tabs > 0

    --- Check if blueprint has at least one setting
    local hasSettings = blueprint.Settings and #blueprint.Settings > 0

    --- Check if blueprint does NOT have both tabs and settings
    if not hasTabs and not hasSettings then
        MCMWarn(0,
            "Blueprint for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            " does not have any tabs or settings. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return true
    elseif hasTabs and hasSettings then
        MCMWarn(0,
            "Blueprint for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            " has both tabs and settings. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return true
    end

    --- Check if blueprint does NOT have sections directly at the top level
    local hasSections = blueprint.Sections and #blueprint.Sections > 0
    if hasSections then
        MCMWarn(0,
            "Sections found directly in blueprint for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return true
    end

    return false
end

--- Verify that all tabs in the blueprint have unique IDs
---@param blueprint table The blueprint data to verify
---@param modGUID string The mod's unique identifier
function DataPreprocessing:VerifyTabIDUniqueness(blueprint, modGUID)
    local tabs = blueprint.Tabs
    if tabs == nil then
        return true
    end

    local tabIDs = {}

    for _, tab in ipairs(tabs) do
        if tabIDs[tab.TabId] then
            MCMWarn(0,
                "Duplicate tab ID found in blueprint for mod: " ..
                Ext.Mod.GetMod(modGUID).Info.Name ..
                ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
            return false
        end
        tabIDs[tab.TabId] = true
    end

    return true
end

--- Verify that all sections in the blueprint have unique IDs
---@param blueprint table The blueprint data to verify
---@param modGUID string The mod's unique identifier
function DataPreprocessing:VerifySectionIDUniqueness(blueprint, modGUID)
    local tabs = blueprint.Tabs
    if tabs == nil then
        return true
    end

    local sectionIDs = {}

    for _, tab in ipairs(tabs) do
        if tab.Sections ~= nil then
            for _, section in ipairs(tab.Sections) do
                if sectionIDs[section.SectionId] then
                    MCMWarn(0,
                        "Duplicate section ID found in blueprint for mod: " ..
                        Ext.Mod.GetMod(modGUID).Info.Name ..
                        ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
                    return false
                end
                sectionIDs[section.SectionId] = true
            end
        end
    end

    return true
end

--- TODO: come up with a good way to verify across tabs and sections, and not only at the top level
--- Verify that all setting IDs in the blueprint are unique
---@param blueprint table The blueprint data to verify
---@param modGUID string The mod's unique identifier
function DataPreprocessing:VerifySettingIDUniqueness(blueprint, modGUID)
    local settings = blueprint.Settings
    if settings == nil then
        return true
    end
    local settingIDs = {}

    for _, setting in ipairs(settings) do
        if setting ~= nil then
            if settingIDs[setting.Id] then
                MCMWarn(0,
                    "Duplicate setting ID found in blueprint for mod: " ..
                    Ext.Mod.GetMod(modGUID).Info.Name ..
                    ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
                return false
            end
            settingIDs[setting.Id] = true
        end
    end

    return true
end

--- Verify all IDs in the blueprint are unique
---@param blueprint table The blueprint data to verify
---@param modGUID string The mod's unique identifier
function DataPreprocessing:VerifyIDUniqueness(blueprint, modGUID)
    return self:VerifyTabIDUniqueness(blueprint, modGUID) and
        self:VerifySectionIDUniqueness(blueprint, modGUID) and
        self:VerifySettingIDUniqueness(blueprint, modGUID)
end

--- Validate the setting data in the blueprint (e.g.: ensure that all IDs are unique, default values are valid, etc.)
---@param blueprint table The blueprint data to validate
---@param modGUID string The mod's unique identifier
function DataPreprocessing:ValidateBlueprintSettings(blueprint, modGUID)
end

--- TODO: validate if blueprint is correct, e.g. settings have unique IDs, etc.
--- Sanitizes blueprint data by removing elements without SchemaVersions and converting string booleans
---@param blueprint table The blueprint data to sanitize
---@param modGUID string The mod's unique identifier
function DataPreprocessing:SanitizeBlueprint(blueprint, modGUID)
    if not self:HasSchemaVersionsEntry(blueprint, modGUID) then
        return
    end

    if self:HasIncorrectStructure(blueprint, modGUID) then
        MCMWarn(0,
            "Blueprint for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            " has incorrect structure anda can't be used. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return
    end

    if not self:VerifyIDUniqueness(blueprint, modGUID) then
        MCMWarn(0,
            "Blueprint for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            " has duplicate IDs and can't be used. Please contact " ..
            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return
    end

    table.convertStringBooleans(blueprint)
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
                        if not self:ValidateSetting(setting, settings[setting:GetId()]) then
                            table.insert(invalidSettings, setting:GetId())
                        end
                    end
                end
            else
                -- Validate settings directly in the tab
                for _, setting in ipairs(tab:GetSettings()) do
                    if not self:ValidateSetting(setting, settings[setting:GetId()]) then
                        table.insert(invalidSettings, setting:GetId())
                    end
                end
            end
        end
    end

    if BlueprintSettings then
        for _, setting in ipairs(BlueprintSettings) do
            if not self:ValidateSetting(setting, settings[setting:GetId()]) then
                table.insert(invalidSettings, setting:GetId())
            end
        end
    end

    return #invalidSettings == 0, invalidSettings
end

--- Validate a single setting based on its type
---@param setting BlueprintSetting The setting to validate
---@param value any The value of the setting
---@return boolean True if the setting is valid, false otherwise
function DataPreprocessing:ValidateSetting(setting, value)
    local validator = SettingValidators[setting:GetType()]
    MCMDebug(2,
        "Validating setting: " ..
        setting:GetId() ..
        " with value: " .. tostring(value) .. " using validator: " .. setting:GetType())

    if not validator then
        MCMWarn(0,
            "No validator found for setting type: " ..
            setting:GetType() .. ". Please contact the mod author about this issue.")
        return false
    end

    if not validator(setting, value) then
        return false
    end

    return true
end

--- Attempt to fix invalid settings by resetting them to default values
---@param blueprint Blueprint The blueprint data
---@param config table<string, any> All the settings for the mod as a flat table of settingId -> value pairs
---@return nil - The config table is updated in place
function DataPreprocessing:ValidateAndFixSettings(blueprint, config)
    local isValid, invalidSettings = DataPreprocessing:ValidateSettings(blueprint, config)
    DataPreprocessing:FixInvalidSettings(blueprint, config, isValid, invalidSettings)

    return config
end

--- Reset list of settings to their default values
---@param blueprint Blueprint The blueprint data
---@param config table<string, any> All the settings for the mod as a flat table of settingId -> value pairs
---@param isValid boolean True if all settings are valid, false otherwise
---@param invalidSettings string[] The IDs of the settings
---@return nil - The config table is updated in place
function DataPreprocessing:FixInvalidSettings(blueprint, config, isValid, invalidSettings)
    if not isValid then
        for _, settingID in ipairs(invalidSettings) do
            local defaultValue = blueprint:RetrieveDefaultValueForSetting(settingID)
            MCMWarn(0,
                "Invalid value for setting '" ..
                settingID ..
                "' (value: " ..
                tostring(config[settingID]) .. ")," .. " resetting it to default value from the blueprint (" ..
                tostring(defaultValue) .. ").")
            config[settingID] = defaultValue
        end
    end
end

--- Check if the data table has a SchemaVersions table and validate its contents
---@param data table The item data to check
---@param modGUID string The UUID of the mod being processed
---@return boolean True if the data table has a SchemaVersions table and it is valid, false otherwise
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
