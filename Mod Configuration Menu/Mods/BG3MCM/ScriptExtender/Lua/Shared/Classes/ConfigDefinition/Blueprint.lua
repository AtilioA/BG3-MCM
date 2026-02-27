---@class Blueprint
---@field private ModUUID string
---@field private SchemaVersion number
---@field private Optional boolean
---@field private ModName? string
---@field private ModDescription? string
---@field private Tabs? BlueprintTab[]
---@field private Settings? BlueprintSetting[]
---@field private Sections? BlueprintSection[]
---@field private Handles? table
---@field private KeybindingSortMode string
Blueprint = _Class:Create("Blueprint", nil, {
    ModUUID = nil,
    ModName = nil,
    ModDescription = nil,
    SchemaVersion = nil,
    Optional = false,
    Tabs = {},
    Sections = {},
    Settings = {},
    Handles = {},
    KeybindingSortMode = "blueprint"
})

function Blueprint:GetModUUID()
    return self.ModUUID
end

function Blueprint:GetSchemaVersion()
    return self.SchemaVersion
end

function Blueprint:GetOptional()
    return self.Optional
end

function Blueprint:GetKeybindingSortMode()
    return self.KeybindingSortMode
end

function Blueprint:GetModName()
    if self.Handles and self.Handles.NameHandle then
        local translatedName = Ext.Loca.GetTranslatedString(self.Handles.NameHandle)
        if translatedName and translatedName ~= "" then
            return translatedName
        end
    end

    local modName = self.ModName
    local modData = Ext.Mod.GetMod(self.ModUUID)
    if (not self.ModName or self.ModName == "") and modData and modData.Info then
        modName = modData.Info.Name
    end

    return modName
end

function Blueprint:SetModName(value)
    self.ModName = value
end

function Blueprint:GetModDescription()
    if self.Handles and self.Handles.DescriptionHandle then
        local translatedDescription = Ext.Loca.GetTranslatedString(self.Handles.DescriptionHandle)
        if translatedDescription and translatedDescription ~= "" then
            return VCString:ReplaceBrWithNewlines(translatedDescription)
        end
    end

    local modDescription = self.ModDescription
    local modData = Ext.Mod.GetMod(self.ModUUID)
    if not self.ModDescription and modData and modData.Info then
        modDescription = modData.Info.Description
    end

    return modDescription
end

function Blueprint:GetHandles()
    return self.Handles
end

--- Returns the tabs of the blueprint, if any.
---@return BlueprintTab[] tabs The tabs of the blueprint
---@return nil - If there are no tabs
function Blueprint:GetTabs()
    return self.Tabs
end

function Blueprint:SetTabs(value)
    self.Tabs = value
end

--- Returns the settings of the blueprint, if any.
---@return BlueprintSetting[] settings The settings of the blueprint
---@return nil - If there are no settings
function Blueprint:GetSettings()
    return self.Settings
end

--- Returns the sections of the blueprint, if any.
---@return BlueprintSection[] sections The sections of the blueprint
---@return nil - If there are no sections
function Blueprint:GetSections()
    return self.Sections
end

function Blueprint:SetSections(value)
    self.Sections = value
end

function Blueprint:SetSettings(value)
    self.Settings = value
end

--- Constructor for the Blueprint class.
--- @param options table
--- @return Blueprint
function Blueprint:New(options)
    local self = setmetatable({}, Blueprint)
    self.ModUUID = options.ModUUID or nil
    self.SchemaVersion = options.SchemaVersion or nil
    self.Settings = options.Settings or nil
    self.Optional = options.Optional or false
    self.ModName = options.ModName or nil
    self.ModDescription = options.ModDescription or nil
    self.Handles = options.Handles or nil
    self.KeybindingSortMode = options.KeybindingSortMode or "alphabetical"
    self.Tabs = {}
    self.Sections = {}
    self.Settings = {}

    if options.Tabs then
        for _, tabOptions in ipairs(options.Tabs) do
            local tab = BlueprintTab:New(tabOptions)
            table.insert(self.Tabs, tab)
        end
    elseif options.Settings then
        self.Settings = {}
        for idx, settingOptions in ipairs(options.Settings) do
            local opts = settingOptions
            local existingSortOrder = settingOptions.Options and settingOptions.Options.SortOrder
            if existingSortOrder == nil then
                opts = {}
                for k, v in pairs(settingOptions) do opts[k] = v end
                opts.Options = opts.Options or {}
                opts.Options.SortOrder = idx
            end
            local setting = BlueprintSetting:New(opts)
            table.insert(self.Settings, setting)
        end
    elseif options.Sections then
        self.Sections = {}
        for _, sectionOptions in ipairs(options.Sections) do
            local section = BlueprintSection:New(sectionOptions)
            table.insert(self.Sections, section)
        end
    end

    return self
end

--- Create a new section in the blueprint
---@param name string The name of the section
---@param description string The description of the section
---@return BlueprintSection section The newly created section
function Blueprint:AddSection(name, description)
    local section = BlueprintSection:New({
        sectionName = name,
        sectionDescription = description
    })

    table.insert(self.Sections, section)

    return section
end

function Blueprint:GetAllSettings()
    local allSettings = {}

    -- Collect root-level Settings if they exist
    for _, setting in ipairs(self.Settings or {}) do
        allSettings[setting:GetId()] = setting
    end

    -- Traverse Tabs and their Sections to collect Settings
    for _, tab in ipairs(self.Tabs or {}) do
        for _, setting in pairs(tab:GetAllSettings() or {}) do
            allSettings[setting:GetId()] = setting
        end
    end

    return allSettings
end

--- Get all settings as an ordered array, preserving blueprint order.
--- This is useful for keybindings where order matters.
---@return BlueprintSetting[]
function Blueprint:GetAllSettingsOrdered()
    local settings = {}

    for _, setting in ipairs(self.Settings or {}) do
        table.insert(settings, setting)
    end

    for _, tab in ipairs(self.Tabs or {}) do
        for _, setting in ipairs(tab:GetAllSettings() or {}) do
            table.insert(settings, setting)
        end
    end

    return settings
end

--- Retrieve the default value for a setting by name
---@param settingId string The name/key of the setting to retrieve the default value for
---@return any setting.Default The default value for the setting
function Blueprint:RetrieveDefaultValueForSetting(settingId)
    local settings = self:GetAllSettings()

    if not settings then
        MCMWarn(1, "No settings found in blueprint. Returning nil as default value.")
        return nil
    end

    if not settings[settingId] then
        MCMWarn(1, "Setting with ID " .. settingId .. " not found in blueprint. Returning nil as default value.")
        return nil
    end

    return settings[settingId]:GetDefault()
end

--- Retrieve all the default values for all the settings in the blueprint
--- @param blueprint Blueprint The blueprint to use for the settings
--- @return table<string, any> settings The plain settings table with default values
function Blueprint:GetDefaultSettingsFromBlueprint(blueprint)
    local settings = {}

    local allSettings = blueprint:GetAllSettings()
    for _, setting in pairs(allSettings) do
        settings[setting:GetId()] = setting:GetDefault()
    end

    return settings
end
