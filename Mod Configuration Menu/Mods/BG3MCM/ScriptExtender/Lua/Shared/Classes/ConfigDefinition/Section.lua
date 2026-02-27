---@class BlueprintSection
---@field private SectionName string
---@field private SectionId string
---@field private SectionDescription string
---@field private VisibleIf table<string, string>
---@field private Options table
---@field private Settings BlueprintSetting[]
---@field private Handles? table
BlueprintSection = _Class:Create("BlueprintSection", nil, {
    SectionName = "",
    SectionId = "",
    SectionDescription = "",
    VisibleIf = "",
    Options = {},
    Tabs = {},
    Settings = {},
    Handles = {}
})

--- Constructor for the BlueprintSection class.
--- @param options table
--- @return BlueprintSection
function BlueprintSection:New(options)
    local self = setmetatable({}, BlueprintSection)
    self.SectionId = options.SectionId or ""
    self.SectionName = options.SectionName or ""
    self.SectionDescription = options.SectionDescription or ""
    self.VisibleIf = options.VisibleIf or ""
    self.Options = options.Options or {}
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

function BlueprintSection:GetLocaName()
    local sectionName = self.SectionName
    if self:GetHandles() then
        if self:GetHandles().NameHandle then
            local translatedName = Ext.Loca.GetTranslatedString(self:GetHandles().NameHandle)
            if translatedName ~= nil and translatedName ~= "" then
                sectionName = translatedName
            end
        end
    end

    return sectionName
end

function BlueprintSection:GetId()
    return self.SectionId
end

function BlueprintSection:GetDescription()
    return self.SectionDescription
end

function BlueprintSection:GetVisibleIf()
    return self.VisibleIf
end

function BlueprintSection:GetSettings()
    return self.Settings
end

function BlueprintSection:SetSectionName(value)
    self.SectionName = value
end

function BlueprintSection:GetOptions()
    return self.Options
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
