---@class Schema
---@field private SchemaVersion number
---@field private Sections table<number, SchemaSection>
Schema = _Class:Create("Schema", nil, {
    SchemaVersion = 1,
    Sections = {}
})

function Schema:GetSchemaVersion()
    return self.SchemaVersion
end

function Schema:GetSections()
    return self.Sections
end

function Schema:SetSections(value)
    self.Sections = value
end

--- Constructor for the Schema class.
--- @class Schema
--- @param options table
function Schema:New(options)
    local self = setmetatable({}, Schema)
    self.SchemaVersion = options.SchemaVersion or 1 -- Default to version 1 if not provided
    self.Sections = options.Sections or {}
    return self
end

--- Create a new section in the schema
---@param name string The name of the section
---@param description string The description of the section
---@return SchemaSection section The newly created section
function Schema:AddSection(name, description)
    local section = SchemaSection:Create({
        sectionName = name,
        sectionDescription = description
    })
    table.insert(self.Sections, section)
    return section
end

--- Retrieve the default value for a setting by name
---@param settingName string The name/key of the setting to retrieve the default value for
---@return any setting.Default The default value for the setting
function Schema:RetrieveDefaultValueForSetting(settingName)
    for _, section in ipairs(self.Sections) do
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
    for _, section in ipairs(schema.Sections) do
        for _, setting in ipairs(section:GetSettings()) do
            settings[setting:GetId()] = setting:GetDefault()
        end
    end
    return settings
end
