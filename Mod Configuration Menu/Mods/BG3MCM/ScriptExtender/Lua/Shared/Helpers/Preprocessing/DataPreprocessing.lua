---@class HelperDataPreprocessing
DataPreprocessing = _Class:Create("HelperDataPreprocessing", nil)


-- TODO: modularize this when the MCM schema has been defined
--- Validate the settings based on the blueprint and collect any invalid settings
---@param blueprint Blueprint The blueprint data
---@param settings BlueprintSetting The settings data
---@return boolean, string[] True if all settings are valid, and a list of invalid settings' IDs
function DataPreprocessing:ValidateSettings(blueprint, settings)
    local invalidSettings = {}

    BlueprintShape:ForEachSetting(blueprint, function(setting)
        if not self:ValidateSetting(setting, settings[setting:GetId()]) then
            table.insert(invalidSettings, setting:GetId())
        end
    end)

    return #invalidSettings == 0, invalidSettings
end

--- Validate a single setting based on its type
---@param setting BlueprintSetting The setting to validate
---@param value MCMSettingValue The value of the setting
---@return boolean True if the setting is valid, false otherwise
function DataPreprocessing:ValidateSetting(setting, value)
    local validator = SettingValidators[setting:GetType()]
    MCMDebug(2,
        "Validating setting: %s with value: %s using validator: %s",
        setting:GetId(), value, setting:GetType())

    if not validator then
        MCMWarn(0,
            "No validator found for setting type: %s. Please contact %s about this issue (mod %s).",
            setting:GetType(),
            Ext.Mod.GetMod(BlueprintPreprocessing.currentmodUUID).Info.Author,
            Ext.Mod.GetMod(BlueprintPreprocessing.currentmodUUID).Info.Name)
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
---@return table<string, any> config The updated config table
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
                "Invalid value for setting '%s' (value: %s), resetting it to default value from the blueprint (%s).",
                settingID,
                Ext.DumpExport(config[settingID]),
                Ext.DumpExport(defaultValue))
            config[settingID] = defaultValue
        end
    end
end

---@param settings table[]|nil
---@return BlueprintSetting[]
function DataPreprocessing:PreprocessSettings(settings)
    local processedSettings = {}

    for _, setting in ipairs(settings or {}) do
        table.insert(processedSettings, BlueprintSetting:New({
            Id = setting.Id,
            OldId = setting.OldId,
            Name = setting.Name,
            VisibleIf = setting.VisibleIf,
            Type = setting.Type,
            Default = setting.Default,
            Description = setting.Description,
            Tooltip = setting.Tooltip,
            Options = setting.Options or {},
            Handles = setting.Handles or {}
        }))
    end

    return processedSettings
end

---@param target BlueprintTab[]
---@param rawTabs table[]|nil
---@param modUUID string
function DataPreprocessing:AppendTabs(target, rawTabs, modUUID)
    for _, rawTab in ipairs(rawTabs or {}) do
        table.insert(target, self:PreprocessTab(rawTab, modUUID) or BlueprintTab:New({}))
    end
end

---@param target BlueprintSection[]
---@param rawSections table[]|nil
---@param modUUID string
function DataPreprocessing:AppendSections(target, rawSections, modUUID)
    for _, rawSection in ipairs(rawSections or {}) do
        table.insert(target, self:PreprocessSection(rawSection, modUUID) or BlueprintSection:New({}))
    end
end

---@param tabData table
---@param modUUID string
---@return BlueprintTab|nil
function DataPreprocessing:PreprocessTab(tabData, modUUID)
    if not (tabData.TabId or tabData.Id) or not (tabData.TabName or tabData.Name) then
        return nil
    end

    local tab = BlueprintTab:New({
        TabId = tabData.TabId or tabData.Id,
        TabName = tabData.TabName or tabData.Name,
        TabDescription = tabData.TabDescription or tabData.Description,
        VisibleIf = tabData.VisibleIf,
        Tabs = {},
        Sections = {},
        Settings = {},
        Handles = tabData.Handles or {}
    })

    tab:AddSetting(self:PreprocessSettings(tabData.Settings))

    self:AppendTabs(tab:GetTabs(), tabData.Tabs, modUUID)
    self:AppendSections(tab:GetSections(), tabData.Sections, modUUID)

    return tab
end

---@param sectionData table
---@param modUUID string
---@return BlueprintSection|nil
function DataPreprocessing:PreprocessSection(sectionData, modUUID)
    if not (sectionData.SectionId or sectionData.Id) or not (sectionData.SectionName or sectionData.Name) then
        return nil
    end

    local section = BlueprintSection:New({
        SectionId = sectionData.SectionId or sectionData.Id,
        SectionName = sectionData.SectionName or sectionData.Name,
        SectionDescription = sectionData.SectionDescription or sectionData.Description,
        VisibleIf = sectionData.VisibleIf,
        -- TODO: validate Options input
        Options = sectionData.Options or {},
        Tabs = {},
        Settings = {},
        Handles = sectionData.Handles or {}
    })

    section.Settings = self:PreprocessSettings(sectionData.Settings)

    self:AppendTabs(section:GetTabs(), sectionData.Tabs, modUUID)

    return section
end

--- Entry point function to preprocess data including SchemaVersion and ModName.
---@param data table The full item data to preprocess
---@param modUUID string The UUID of the mod that the item data belongs to
---@return PreprocessedBlueprintData The preprocessed data
function DataPreprocessing:PreprocessData(data, modUUID)
    local preprocessedData = {
        ModUUID = modUUID,
        SchemaVersion = data.SchemaVersion,
        Optional = data.Optional,
        ModName = data.ModName,
        ModDescription = data.ModDescription,
        KeybindingSortMode = data.KeybindingSortMode or KeybindingSortMode.DEFAULT,
        Handles = data.Handles,
        Tabs = {},
        Sections = {},
        Settings = {}
    }

    self:AppendTabs(preprocessedData.Tabs, data.Tabs, modUUID)
    self:AppendSections(preprocessedData.Sections, data.Sections, modUUID)
    preprocessedData.Settings = self:PreprocessSettings(data.Settings)

    return preprocessedData
end
