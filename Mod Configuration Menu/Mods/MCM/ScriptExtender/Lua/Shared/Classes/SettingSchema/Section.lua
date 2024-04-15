---@class SchemaSection
---@field private SectionName string
---@field private SectionDescription string
---@field private Settings SchemaSetting[]
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

--- Constructor for the SchemaSection class.
--- @param options table
function SchemaSection:New(options)
    local self = setmetatable({}, SchemaSection)
    self.SectionName = options.sectionName or ""
    self.SectionDescription = options.sectionDescription or ""
    self.Settings = {}

    if options.Settings then
        for _, settingOptions in ipairs(options.Settings) do
            local setting = SchemaSetting:New(settingOptions)
            table.insert(self.Settings, setting)
        end
    end

    return self
end

function SchemaSection:AddSetting(name, type, default, description, options, sectionName)
    local setting = SchemaSetting:New({
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
