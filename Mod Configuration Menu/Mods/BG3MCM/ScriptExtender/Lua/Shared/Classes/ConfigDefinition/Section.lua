---@class BlueprintSection
---@field private SectionName string
---@field private SectionDescription string
---@field private Settings BlueprintSetting[]
---@field private Handles? table
BlueprintSection = _Class:Create("BlueprintSection", nil, {
    SectionName = "",
    SectionDescription = "",
    Tabs = {},
    Settings = {},
    Handles = {}
})

--- Constructor for the BlueprintSection class.
--- @param options table
function BlueprintSection:New(options)
    local self = setmetatable({}, BlueprintSection)
    self.SectionId = options.SectionId or ""
    self.SectionName = options.SectionName or ""
    self.SectionDescription = options.SectionDescription or ""
    self.Tabs = {}
    self.Settings = {}
    self.Handles = options.Handles

    if options.Tabs then
        for _, tabOptions in ipairs(options.Tabs) do
            local tab = BlueprintTab:New(tabOptions)
            table.insert(self.Tabs, tab)
        end
    end

    if options.Settings then
        for _, settingOptions in ipairs(options.Settings) do
            local setting = BlueprintSetting:New(settingOptions)
            table.insert(self.Settings, setting)
        end
    end

    return self
end

function BlueprintSection:GetSectionName()
    return self.SectionName
end

function BlueprintSection:GetSectionDescription()
    return self.SectionDescription
end

function BlueprintSection:GetSettings()
    return self.Settings
end

function BlueprintSection:SetSectionName(value)
    self.SectionName = value
end

function BlueprintSection:GetHandles()
    return self.Handles
end

function BlueprintSection:SetSectionDescription(value)
    self.SectionDescription = value
end

function BlueprintSection:AddSetting(name, type, default, description, options, sectionName)
    local setting = BlueprintSetting:New({
        Name = name,
        Type = type,
        Default = default,
        Description = description,
        BlueprintSection = sectionName or self.SectionName,
        Options = options or {}
    })
    table.insert(self.Settings, setting)
    return self
end
