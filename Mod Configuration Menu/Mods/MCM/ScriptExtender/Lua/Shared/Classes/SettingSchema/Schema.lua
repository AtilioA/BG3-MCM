---@class Schema
---@field private SchemaVersion number
---@field private Tabs? SchemaTab[]
---@field private Settings? SchemaSetting[]
Schema = _Class:Create("Schema", nil, {
    SchemaVersion = 1,
    Tabs = {}
})

function Schema:GetSchemaVersion()
    return self.SchemaVersion
end

function Schema:GetTabs()
    return self.Tabs
end

function Schema:SetTabs(value)
    self.Tabs = value
end

--- Returns the settings of the schema, if any.
---@return SchemaSetting[] settings The settings of the schema
---@return nil If there are no settings
function Schema:GetSettings()
    return self.Settings
end

function Schema:SetSettings(value)
    self.Tabs = value
end

--- Constructor for the Schema class.
--- @class Schema
--- @param options table
function Schema:New(options)
    local self = setmetatable({}, Schema)
    self.SchemaVersion = options.SchemaVersion or 1 -- Default to version 1 if not provided

    -- Call SchemaSection constructor for each section
    self.Tabs = {}
    if options.Tabs then
        for _, tabOptions in ipairs(options.Tabs) do
            local tab = SchemaTab:New(tabOptions)
            table.insert(self.Tabs, tab)
        end
    end

    return self
end

--- Create a new section in the schema
---@param name string The name of the section
---@param description string The description of the section
---@return SchemaSection section The newly created section
function Schema:AddSection(name, description)
    local section = SchemaSection:New({
        sectionName = name,
        sectionDescription = description
    })
    table.insert(self.Tabs, section)
    return section
end

--- Retrieve the default value for a setting by name
---@param settingName string The name/key of the setting to retrieve the default value for
---@return any setting.Default The default value for the setting
function Schema:RetrieveDefaultValueForSetting(settingName)
    for _, section in ipairs(self.Tabs) do
        for _, setting in ipairs(section:GetSettings()) do
            if setting:GetId() == settingName then
                return setting:GetDefault()
            end
        end
    end

    return nil
end

--- Retrieve all the default values for all the settings in the schema
--- @param schema Schema The schema to use for the settings
--- @return table<string, any> settings The plain settings table with default values
function Schema:GetDefaultSettingsFromSchema(schema)
    local settings = {}

    if schema.Tabs then
        for _, tab in ipairs(schema.Tabs) do
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
    elseif schema.Settings then
        for _, setting in ipairs(schema.Settings) do
            settings[setting:GetId()] = setting:GetDefault()
        end
    end

    return settings
end
