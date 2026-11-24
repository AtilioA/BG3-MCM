---@class HelperDataPreprocessing
DataPreprocessing = _Class:Create("HelperDataPreprocessing", nil)


-- TODO: modularize this when the MCM schema has been defined
--- Validate the settings based on the blueprint and collect any invalid settings
---@param blueprint Blueprint The blueprint data
---@param settings BlueprintSetting The settings data
---@return string[] invalidSettings The IDs of the invalid settings
function DataPreprocessing:ValidateSettings(blueprint, settings)
    local invalidSettings = {}

    BlueprintShape:ForEachSetting(blueprint, function(setting)
        if not self:ValidateSetting(setting, settings[setting:GetId()]) then
            table.insert(invalidSettings, setting:GetId())
        end
    end)

    return invalidSettings
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
    DataPreprocessing:FixInvalidSettings(blueprint, config, DataPreprocessing:ValidateSettings(blueprint, config))

    return config
end

--- Reset list of settings to their default values
---@param blueprint Blueprint The blueprint data
---@param config table<string, any> All the settings for the mod as a flat table of settingId -> value pairs
---@param invalidSettings string[] The IDs of the settings
---@return nil - The config table is updated in place
function DataPreprocessing:FixInvalidSettings(blueprint, config, invalidSettings)
    for _, settingID in ipairs(invalidSettings) do
        local setting = BlueprintShape:GetSettingById(blueprint, settingID)
        local defaultValue = blueprint:RetrieveDefaultValueForSetting(settingID)
        if setting and self:ValidateSetting(setting, defaultValue) then
            MCMWarn(0,
                "Invalid value for setting '%s' (value: %s), resetting it to default value from the blueprint (%s).",
                settingID,
                Ext.DumpExport(config[settingID]),
                Ext.DumpExport(defaultValue))
            config[settingID] = defaultValue
        else
            MCMWarn(0,
                "Invalid value for setting '%s' (value: %s). The blueprint default (%s) is also invalid, so the setting could not be repaired. Please contact the mod author about this issue.",
                settingID,
                Ext.DumpExport(config[settingID]),
                Ext.DumpExport(defaultValue))
        end
    end
end

local function sanitizeOptionalString(value, fieldName, contextLabel)
    if value ~= nil and type(value) ~= "string" then
        MCMWarn(0, "Ignoring invalid %s for %s", fieldName, contextLabel)
        return nil
    end
    return value
end

local function sanitizeHandles(value, contextLabel, defaultTable)
    if value ~= nil and type(value) ~= "table" then
        MCMWarn(0, "Ignoring invalid Handles for %s", contextLabel)
        return defaultTable
    end
    return value or defaultTable
end

---@param value unknown
---@return unknown
local function coerceLegacyBoolean(value)
    if value == "true" then
        return true
    elseif value == "false" then
        return false
    end
    return value
end

---@param tbl table|nil
local function coerceLegacyBooleanOptions(tbl)
    if type(tbl) ~= "table" then
        return
    end
    for key, value in pairs(tbl) do
        if LegacyCompat.CoercedBooleanFields[key] and (value == "true" or value == "false") then
            tbl[key] = value == "true"
        end
    end
end

---@param modUUID string|nil
---@return string modDisplayName
---@return string contactSuffix
local function formatModAttribution(modUUID)
    local mod = modUUID and Ext.Mod.GetMod(modUUID) or nil
    local info = mod and mod.Info or nil
    local modName = (info and info.Name and info.Name ~= "") and ("'" .. info.Name .. "'") or tostring(modUUID)
    local contactSuffix = (info and info.Author and info.Author ~= "")
        and (" Please contact " .. info.Author .. " about this issue.")
        or ""
    return modName, contactSuffix
end

---@param tbl table|nil
---@param allowedKeys table<string, boolean>|nil
---@param scopeLabel string
---@param modUUID string|nil
local function warnUnknownKeys(tbl, allowedKeys, scopeLabel, modUUID)
    if type(tbl) ~= "table" or type(allowedKeys) ~= "table" then
        return
    end
    local modName, contactSuffix = formatModAttribution(modUUID)
    for key, _ in pairs(tbl) do
        if type(key) ~= "string" or not allowedKeys[key] then
            MCMWarn(0, "Unknown blueprint key '%s' in %s for mod %s.%s", tostring(key), scopeLabel, modName, contactSuffix)
        end
    end
end

---@param setting table
---@param settingLabel string
---@param modUUID string|nil
local function checkSettingUnknownKeys(setting, settingLabel, modUUID)
    warnUnknownKeys(setting, BlueprintContract.AllowedKeys.Setting, settingLabel, modUUID)

    if type(setting.Handles) == "table" then
        warnUnknownKeys(setting.Handles, BlueprintContract.AllowedKeys.SettingHandles, settingLabel .. " Handles", modUUID)
        if type(setting.Handles.EventButtonHandles) == "table" then
            warnUnknownKeys(
                setting.Handles.EventButtonHandles,
                BlueprintContract.AllowedKeys.EventButtonHandles,
                settingLabel .. " EventButtonHandles",
                modUUID
            )
            if type(setting.Handles.EventButtonHandles.ConfirmDialogHandles) == "table" then
                warnUnknownKeys(
                    setting.Handles.EventButtonHandles.ConfirmDialogHandles,
                    BlueprintContract.AllowedKeys.ConfirmDialogHandles,
                    settingLabel .. " ConfirmDialogHandles",
                    modUUID
                )
            end
        end
    end

    if type(setting.Options) == "table" then
        local canonicalType = LegacyCompat.CanonicalTypeAliases[setting.Type] or setting.Type
        local allowedOptionKeys = BlueprintContract.AllowedKeys.OptionsByType[canonicalType]
        if allowedOptionKeys then
            warnUnknownKeys(setting.Options, allowedOptionKeys, settingLabel .. " Options", modUUID)
        end
        if canonicalType == "event_button" then
            if type(setting.Options.ConfirmDialog) == "table" then
                warnUnknownKeys(
                    setting.Options.ConfirmDialog,
                    BlueprintContract.AllowedKeys.ConfirmDialog,
                    settingLabel .. " Options.ConfirmDialog",
                    modUUID
                )
            end
            if type(setting.Options.Icon) == "table" then
                warnUnknownKeys(
                    setting.Options.Icon,
                    BlueprintContract.AllowedKeys.Icon,
                    settingLabel .. " Options.Icon",
                    modUUID
                )
                if type(setting.Options.Icon.Size) == "table" then
                    warnUnknownKeys(
                        setting.Options.Icon.Size,
                        BlueprintContract.AllowedKeys.IconSize,
                        settingLabel .. " Options.Icon.Size",
                        modUUID
                    )
                end
            end
        end
    end
end

---@param settings table[]|nil
---@param modUUID string|nil
---@return BlueprintSetting[]
function DataPreprocessing:PreprocessSettings(settings, modUUID)
    local processedSettings = {}
    local effectiveModUUID = modUUID or BlueprintPreprocessing.currentmodUUID

    for _, setting in ipairs(settings or {}) do
        local settingLabel = "setting " .. tostring(setting.Id)
        checkSettingUnknownKeys(setting, settingLabel, effectiveModUUID)
        coerceLegacyBooleanOptions(setting.Options)
        table.insert(processedSettings, BlueprintSetting:New({
            Id = setting.Id,
            OldId = setting.OldId,
            Name = sanitizeOptionalString(setting.Name, "Name", settingLabel),
            VisibleIf = setting.VisibleIf,
            Type = setting.Type,
            Default = setting.Default,
            Description = sanitizeOptionalString(setting.Description, "Description", settingLabel),
            Tooltip = sanitizeOptionalString(setting.Tooltip, "Tooltip", settingLabel),
            Options = setting.Options,
            Handles = sanitizeHandles(setting.Handles, settingLabel, nil)
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
    local tabId = tabData.TabId or tabData.Id
    local tabLabel = "tab " .. tostring(tabId)
    warnUnknownKeys(tabData, BlueprintContract.AllowedKeys.Tab, tabLabel, modUUID)
    if type(tabData.Handles) == "table" then
        warnUnknownKeys(tabData.Handles, BlueprintContract.AllowedKeys.TabHandles, tabLabel .. " Handles", modUUID)
    end

    if not tabId or not (tabData.TabName or tabData.Name) then
        return nil
    end

    local tab = BlueprintTab:New({
        TabId = tabId,
        TabName = sanitizeOptionalString(tabData.TabName or tabData.Name, "TabName", tabLabel),
        TabDescription = sanitizeOptionalString(tabData.TabDescription or tabData.Description, "TabDescription", tabLabel),
        VisibleIf = tabData.VisibleIf,
        Tabs = {},
        Sections = {},
        Settings = {},
        Handles = sanitizeHandles(tabData.Handles, tabLabel, {})
    })

    tab.Settings = self:PreprocessSettings(tabData.Settings, modUUID)

    self:AppendTabs(tab:GetTabs(), tabData.Tabs, modUUID)
    self:AppendSections(tab:GetSections(), tabData.Sections, modUUID)

    return tab
end

---@param sectionData table
---@param modUUID string
---@return BlueprintSection|nil
function DataPreprocessing:PreprocessSection(sectionData, modUUID)
    local sectionId = sectionData.SectionId or sectionData.Id
    local sectionLabel = "section " .. tostring(sectionId)
    warnUnknownKeys(sectionData, BlueprintContract.AllowedKeys.Section, sectionLabel, modUUID)
    if type(sectionData.Options) == "table" then
        warnUnknownKeys(sectionData.Options, BlueprintContract.AllowedKeys.SectionOptions, sectionLabel .. " Options", modUUID)
        coerceLegacyBooleanOptions(sectionData.Options)
    end
    if type(sectionData.Handles) == "table" then
        warnUnknownKeys(sectionData.Handles, BlueprintContract.AllowedKeys.SectionHandles, sectionLabel .. " Handles", modUUID)
    end

    if not sectionId or not (sectionData.SectionName or sectionData.Name) then
        return nil
    end

    local section = BlueprintSection:New({
        SectionId = sectionId,
        SectionName = sanitizeOptionalString(sectionData.SectionName or sectionData.Name, "SectionName", sectionLabel),
        SectionDescription = sanitizeOptionalString(sectionData.SectionDescription or sectionData.Description, "SectionDescription", sectionLabel),
        VisibleIf = sectionData.VisibleIf,
        Options = sectionData.Options,
        Tabs = {},
        Settings = {},
        Handles = sanitizeHandles(sectionData.Handles, sectionLabel, {})
    })

    section.Settings = self:PreprocessSettings(sectionData.Settings, modUUID)

    self:AppendTabs(section:GetTabs(), sectionData.Tabs, modUUID)

    return section
end

--- Entry point function to preprocess data including SchemaVersion and ModName.
---@param data table The full item data to preprocess
---@param modUUID string The UUID of the mod that the item data belongs to
---@return PreprocessedBlueprintData The preprocessed data
function DataPreprocessing:PreprocessData(data, modUUID)
    local modLabel = "mod " .. tostring(modUUID)
    warnUnknownKeys(data, BlueprintContract.AllowedKeys.Root, "root", modUUID)
    if type(data.Handles) == "table" then
        warnUnknownKeys(data.Handles, BlueprintContract.AllowedKeys.TopLevelHandles, modLabel .. " Handles", modUUID)
    end

    local listFolder = data.ListFolder
    if type(listFolder) == "string" then listFolder = listFolder:match("^%s*(.-)%s*$") end
    if listFolder ~= nil and (type(listFolder) ~= "string" or listFolder:match("^%s*$")) then
        MCMWarn(0, "Ignoring invalid ListFolder for mod %s", modUUID)
        listFolder = nil
    end
    local preprocessedData = {
        ListFolder = listFolder,
        ModUUID = modUUID,
        SchemaVersion = data.SchemaVersion,
        Optional = coerceLegacyBoolean(data.Optional),
        ModName = sanitizeOptionalString(data.ModName, "ModName", modLabel),
        ModDescription = sanitizeOptionalString(data.ModDescription, "ModDescription", modLabel),
        KeybindingSortMode = data.KeybindingSortMode or KeybindingSortMode.DEFAULT,
        HiddenFromList = coerceLegacyBoolean(data.HiddenFromList),
        Handles = sanitizeHandles(data.Handles, modLabel, nil),
        Tabs = {},
        Sections = {},
        Settings = {}
    }

    self:AppendTabs(preprocessedData.Tabs, data.Tabs, modUUID)
    self:AppendSections(preprocessedData.Sections, data.Sections, modUUID)
    preprocessedData.Settings = self:PreprocessSettings(data.Settings, modUUID)

    return preprocessedData
end
