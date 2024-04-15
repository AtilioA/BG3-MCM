---@class SchemaSection
---@field private SectionName string
---@field private SectionDescription string
---@field private Settings table<number, SchemaSetting>
SchemaSection = _Class:Create("SchemaSection", nil, {
    SectionName = "",
    SectionDescription = "",
    Settings = {}
})

function SchemaSection:GetSectionName()
    return self.SectionName
end

function SchemaSection:GetSectionDescription()
    return self.SectionDescription
end

function SchemaSection:GetSettings()
    return self.Settings
end

function SchemaSection:SetSectionName(value)
    self.SectionName = value
end

function SchemaSection:SetSectionDescription(value)
    self.SectionDescription = value
end

function SchemaSection:AddSetting(name, type, default, description, options, sectionName)
    local setting = SchemaSetting:Create({
        Name = name,
        Type = type,
        Default = default,
        Description = description,
        SchemaSection = sectionName or self.SectionName,
        Options = options or {}
    })
    table.insert(self.Settings, setting)
    return self
end
