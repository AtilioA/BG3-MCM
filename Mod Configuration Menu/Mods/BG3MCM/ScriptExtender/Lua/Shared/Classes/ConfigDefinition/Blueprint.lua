---@class Blueprint
---@field private SchemaVersion number
---@field private Tabs? BlueprintTab[]
---@field private Settings? BlueprintSetting[]
---@field private Handles table
Blueprint = _Class:Create("Blueprint", nil, {
    SchemaVersion = 1,
    Tabs = {},
    Handles = {}
})

function Blueprint:GetSchemaVersion()
    return self.SchemaVersion
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
    self.SchemaVersion = options.SchemaVersion or 1 -- Default to version 1 if not provided

    -- Call BlueprintSection constructor for each section
    self.Tabs = {}
    if options.Tabs then
        for _, tabOptions in ipairs(options.Tabs) do
            local tab = BlueprintTab:New(tabOptions)
            table.insert(self.Tabs, tab)
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

--- Retrieve the default value for a setting by name
---@param settingId string The name/key of the setting to retrieve the default value for
---@return any setting.Default The default value for the setting
function Blueprint:RetrieveDefaultValueForSetting(settingId)
    -- TODO: CLEAN THIS GODAWFUL MESS UP
    local tabs = self:GetTabs()
    if tabs then
        for _, tab in ipairs(tabs) do
            local sections = tab:GetSections()
            local settings = tab:GetSettings()

            if sections then
                for _, section in ipairs(sections) do
                    for _, setting in ipairs(section:GetSettings()) do
                        if setting:GetId() == settingId then
                            return setting:GetDefault()
                        end
                    end
                end
            end

            if settings then
                for _, setting in ipairs(settings) do
                    if setting:GetId() == settingId then
                        return setting:GetDefault()
                    end
                end
            end
        end
    end

    local settings = self:GetSettings()
    if settings then
        for _, setting in ipairs(settings) do
            if setting:GetId() == settingId then
                return setting:GetDefault()
            end
        end
    end

    return nil
end

--- Retrieve all the default values for all the settings in the blueprint
--- @param blueprint Blueprint The blueprint to use for the settings
--- @return table<string, any> settings The plain settings table with default values
function Blueprint:GetDefaultSettingsFromBlueprint(blueprint)
    local settings = {}

    if blueprint.Tabs then
        for _, tab in ipairs(blueprint.Tabs) do
            local tabSections = tab:GetSections()
            local tabSettings = tab:GetSettings()

            if tabSections then
                for _, section in ipairs(tab:GetSections()) do
                    for _, setting in ipairs(section:GetSettings()) do
                        settings[setting:GetId()] = setting:GetDefault()
                    end
                end
            end

            if tabSettings then
                for _, setting in ipairs(tab:GetSettings()) do
                    settings[setting:GetId()] = setting:GetDefault()
                end
            end
        end
    elseif blueprint.Settings then
        for _, setting in ipairs(blueprint.Settings) do
            settings[setting:GetId()] = setting:GetDefault()
        end
    end

    return settings
end
