---@class HelperDataPreprocessing
DataPreprocessing = _Class:Create("HelperDataPreprocessing", nil)


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
            setting:GetType() ..
            ". Please contact " ..
            Ext.Mod.GetMod(BlueprintPreprocessing.currentmodUUID).Info.Author ..
            " about this issue (mod " .. Ext.Mod.GetMod(BlueprintPreprocessing.currentmodUUID).Info.Name .. ").")
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
                Ext.DumpExport(config[settingID]) .. ")," .. " resetting it to default value from the blueprint (" ..
                Ext.DumpExport(defaultValue) .. ").")
            config[settingID] = defaultValue
        end
    end
end

--- Recursively preprocess tabs and sections to create Blueprint instances for each element found.
---@param elementData table The current tab or section data to preprocess.
---@param modUUID string The UUID of the mod that the item data belongs to.
---@return table - The preprocessed tab or section data.
function DataPreprocessing:RecursivePreprocess(elementData, modUUID)
    local processedData = {}

    if elementData.TabName then
        processedData = BlueprintTab:New({
            TabId = elementData.TabId or elementData.Id,
            TabName = elementData.TabName or elementData.Name,
            TabDescription = elementData.TabDescription or elementData.Description,
            VisibleIf = elementData.VisibleIf,
            Tabs = elementData.Tabs or {}, -- Tabs might also have nested Tabs
            Sections = elementData.Sections or {},
            -- Settings = elementData.Settings or {},
            Handles = elementData.Handles or {}
        })

        -- Process nested Tabs if they exist
        if elementData.Tabs then
            for _, nestedTab in ipairs(elementData.Tabs) do
                table.insert(processedData.Tabs, self:RecursivePreprocess(nestedTab, modUUID))
            end
        end
    end

    if elementData.SectionName then
        processedData = BlueprintSection:New({
            SectionId = elementData.SectionId or elementData.Id,
            SectionName = elementData.SectionName or elementData.Name,
            SectionDescription = elementData.SectionDescription or elementData.Description,
            VisibleIf = elementData.VisibleIf,
            -- TODO: validate Options input
            Options = elementData.Options or {},
            Tabs = elementData.Tabs or {}, -- Sections might also have nested Tabs
            -- Settings = elementData.Settings or {},
            Handles = elementData.Handles or {}
        })

        -- Process nested Tabs in Sections if they exist
        if elementData.Tabs then
            for _, nestedTab in ipairs(elementData.Tabs) do
                table.insert(processedData.Tabs, self:RecursivePreprocess(nestedTab, modUUID))
            end
        end
    end

    -- Common processing for Settings in both Tabs and Sections
    for _, setting in ipairs(elementData.Settings or {}) do
        local newSetting = BlueprintSetting:New({
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
        })
        table.insert(processedData.Settings, newSetting)
    end

    return processedData
end

--- Entry point function to preprocess data including SchemaVersion and ModName.
---@param data table The full item data to preprocess
---@param modUUID string The UUID of the mod that the item data belongs to
---@return table<string, BlueprintSetting>|nil The preprocessed data, or nil if preprocessing failed
function DataPreprocessing:PreprocessData(data, modUUID)
    local preprocessedData = {
        ModUUID = modUUID,
        SchemaVersion = data.SchemaVersion,
        Optional = data.Optional,
        ModName = data.ModName,
        ModDescription = data.ModDescription,
        KeybindingSortMode = data.KeybindingSortMode,
        Handles = data.Handles,
        Tabs = {},
        Settings = {}
    }

    -- Recursively process each top-level Tab
    for _, tab in ipairs(data.Tabs or {}) do
        table.insert(preprocessedData.Tabs, self:RecursivePreprocess(tab, modUUID))
    end

    -- Process each top-level Setting
    for _, setting in ipairs(data.Settings or {}) do
        table.insert(preprocessedData.Settings, BlueprintSetting:New(setting))
    end

    return preprocessedData
end
