---@class SchemaSection
---@field sectionName string
---@field sectionDescription string
---@field settings table<number, SchemaSetting>
SchemaSection = _Class:Create("SchemaSection", nil, {
    sectionName = "",
    sectionDescription = "",
    settings = {}
})

function SchemaSection:AddSetting(name, type, default, description, options, sectionName)
    local setting = SchemaSetting:Create({
        Name = name,
        Type = type,
        Default = default,
        Description = description,
        SchemaSection = sectionName or self.sectionName,
        Options = options or {}
    })
    table.insert(self.settings, setting)
    return self
end
