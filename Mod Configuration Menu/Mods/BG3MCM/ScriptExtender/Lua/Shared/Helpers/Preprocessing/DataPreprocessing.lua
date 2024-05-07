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
