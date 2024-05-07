---@class Blueprint
---@field private SchemaVersion number
---@field private ModName? string
---@field private Tabs? BlueprintTab[]
---@field private Settings? BlueprintSetting[]
---@field private Handles? table
Blueprint = _Class:Create("Blueprint", nil, {
    ModName = nil,
    SchemaVersion = nil,
    Tabs = {},
    Handles = {}
})

function Blueprint:GetSchemaVersion()
    return self.SchemaVersion
end

function Blueprint:GetModName()
    return self.ModName
end

function Blueprint:SetModName(value)
    self.ModName = value
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
    self.Tabs = value
end

--- Constructor for the Blueprint class.
--- @class Blueprint
--- @param options table
function Blueprint:New(options)
    local self = setmetatable({}, Blueprint)
    self.SchemaVersion = options.SchemaVersion or nil
    self.ModName = options.ModName or nil

    -- Call BlueprintSection constructor for each section
    self.Tabs = {}
    if options.Tabs then
        for _, tabOptions in ipairs(options.Tabs) do
            local tab = BlueprintTab:New(tabOptions)
            table.insert(self.Tabs, tab)
        end
        -- Only one of Tabs or Settings should be present
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

-- TODO: use throughout the codebase, etc
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
