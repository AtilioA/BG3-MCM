---@class BlueprintSetting
---@field private Id string
---@field private OldId string
---@field private Name string
---@field private Type string
---@field private VisibleIf table<string, string>
---@field private Default any
---@field private Description string
---@field private Tooltip string
---@field private Section string
---@field private Options table
---@field private Handles table
BlueprintSetting = _Class:Create("BlueprintSetting", nil, {
    Id = "",
    OldId = "",
    Name = "",
    Type = "",
    VisibleIf = "",
    Default = nil,
    Description = "",
    Tooltip = "",
    Section = "General",
    Options = {},
    Handles = {}
    -- TODO: Show setting on UI only when other settings are set to specific values?
    -- ShowWhen = { SettingId = "", Value = "" }
})

--- Constructor for the BlueprintSetting class.
--- @param options table
function BlueprintSetting:New(options)
    local self = setmetatable({}, BlueprintSetting)

    if options.Id ~= nil then
        self.Id = options.Id
    end

    if options.OldId ~= nil then
        self.OldId = options.OldId
    else
        self.OldId = ""
    end

    if options.Name ~= nil then
        self.Name = options.Name
    else
        self.Name = ""
    end

    if options.Type ~= nil then
        self.Type = options.Type
    else
        self.Type = ""
    end

    self.VisibleIf = options.VisibleIf or ""

    self.Default = options.Default

    if options.Description ~= nil then
        self.Description = options.Description
    else
        self.Description = ""
    end

    if options.Tooltip ~= nil then
        self.Tooltip = options.Tooltip
    else
        self.Tooltip = ""
    end

    self.Options = options.Options or {}
    self.Handles = options.Handles or {}

    return self
end

function BlueprintSetting:GetName()
    return self.Name
end

function BlueprintSetting:GetLocaName()
    if not self.Name then
        return self:GetId()
    end

    if self.Handles and self.Handles.NameHandle then
        local translatedName = Ext.Loca.GetTranslatedString(self.Handles.NameHandle)
        if translatedName and translatedName ~= "" then
            return translatedName
        end
    end

    return self.Name
end

function BlueprintSetting:GetId()
    return self.Id
end

function BlueprintSetting:GetOldId()
    return self.OldId
end

function BlueprintSetting:GetType()
    return self.Type
end

function BlueprintSetting:GetVisibleIf()
    return self.VisibleIf
end

function BlueprintSetting:GetDefault()
    return self.Default
end

-- REVIEW: GetLoca- or just always use handle logic? I don't see a reason to offer a way to not use handles
function BlueprintSetting:GetDescription()
    local descriptionText = self.Description or ""

    if self.Handles and self.Handles.DescriptionHandle then
        local translatedDescription = Ext.Loca.GetTranslatedString(self.Handles.DescriptionHandle)
        if translatedDescription and translatedDescription ~= "" then
            descriptionText = translatedDescription
        end
    end

    return descriptionText
end

function BlueprintSetting:GetTooltip()
    local tooltipText = self.Tooltip or ""

    if self.Handles and self.Handles.TooltipHandle then
        local translatedTooltip = Ext.Loca.GetTranslatedString(self.Handles.TooltipHandle)
        if translatedTooltip and translatedTooltip ~= "" then
            tooltipText = translatedTooltip
        end
    end

    return tooltipText
end

function BlueprintSetting:GetSection()
    return self.Section
end

function BlueprintSetting:GetOptions()
    return self.Options
end

function BlueprintSetting:GetHandles()
    return self.Handles
end

function BlueprintSetting:GetSortOrder()
    return self.Options and self.Options.SortOrder
end

function BlueprintSetting:SetSortOrder(value)
    self.Options = self.Options or {}
    self.Options.SortOrder = value
end

function BlueprintSetting:SetName(value)
    self.Name = value
end

function BlueprintSetting:SetId(value)
    self.Id = value
end

function BlueprintSetting:SetType(value)
    self.Type = value
end

function BlueprintSetting:SetDefault(value)
    self.Default = value
end

function BlueprintSetting:SetDescription(value)
    self.Description = value
end

function BlueprintSetting:SetTooltip(value)
    self.Tooltip = value
end

function BlueprintSetting:SetSection(value)
    self.Section = value
end

function BlueprintSetting:SetOptions(value)
    self.Options = value
end

function BlueprintSetting:SetHandles(value)
    self.Handles = value
end

-- --- Create a new BlueprintSetting instance
-- ---@param settingData table The setting data from the MCM blueprint
-- function BlueprintSetting:New(settingData)
--     local obj = _Class:New(self)
--     obj:Init(settingData)
--     return obj
-- end

--- Get the current value of the setting
---@return any
function BlueprintSetting:GetValue()
    return self.Default
end

--- Set the value of the setting
---@param value any
function BlueprintSetting:SetValue(value)
end

--- Reset the setting to its default value
function BlueprintSetting:ResetToDefault()
end
