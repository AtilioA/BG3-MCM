---@class Schema
---@field schemaVersion number
---@field sections table<number, SchemaSection>
Schema = _Class:Create("Schema", nil, {
    schemaVersion = 1,
    sections = {}
})

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
    table.insert(self.sections, section)
    return section
end

--- Retrieve the default value for a setting by name
---@param settingName string The name/key of the setting to retrieve the default value for
---@return any setting.Default The default value for the setting
function Schema:RetrieveDefaultValueForSetting(settingName)
    for _, section in ipairs(self.Sections) do
        for _, setting in ipairs(section.Settings) do
            if setting.Name == settingName then
                return setting.Default
            end
        end
    end

    return nil
end
