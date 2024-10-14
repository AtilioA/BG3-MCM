---@class Blueprint
---@field private ModUUID string
---@field private SchemaVersion number
---@field private Optional boolean
---@field private ModName? string
---@field private ModDescription? string
---@field private Tabs? BlueprintTab[]
---@field private Settings? BlueprintSetting[]
---@field private Handles? table
Blueprint = _Class:Create("Blueprint", nil, {
    ModUUID = nil,
    ModName = nil,
    ModDescription = nil,
    SchemaVersion = nil,
    Optional = false,
    Tabs = {},
    Handles = {}
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

function Blueprint:GetModName()
    if self.Handles and self.Handles.NameHandle then
        local translatedName = Ext.Loca.GetTranslatedString(self.Handles.NameHandle)
        if translatedName and translatedName ~= "" then
            return translatedName
        end
    end
    return self.ModName or ""
end

function Blueprint:SetModName(value)
    self.ModName = value
end

function Blueprint:GetModDescription()
    if self.Handles and self.Handles.DescriptionHandle then
        local translatedDescription = Ext.Loca.GetTranslatedString(self.Handles.DescriptionHandle)
        if translatedDescription and translatedDescription ~= "" then
            return translatedDescription
        end
    end
    return self.ModDescription or ""
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
    self.ModName = options.ModName or nil
    self.ModDescription = options.ModDescription or nil
    self.Handles = options.Handles or nil
    self.Tabs = {}

    -- Call BlueprintSection constructor for each section
    if options.Tabs then
        for _, tabOptions in ipairs(options.Tabs) do
            local tab = BlueprintTab:New(tabOptions)
            table.insert(self.Tabs, tab)
        end
    elseif options.Settings then
        self.Settings = {}
        for _, settingOptions in ipairs(options.Settings) do
            local setting = BlueprintSetting:New(settingOptions)
            table.insert(self.Settings, setting)
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

    table.insert(self.Tabs, section)

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
