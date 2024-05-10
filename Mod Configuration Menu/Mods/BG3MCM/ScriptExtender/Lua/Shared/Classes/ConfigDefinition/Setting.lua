---@class BlueprintSetting
---@field private Id string
---@field private Name string
---@field private Type string
---@field private Default any
---@field private Description string
---@field private Tooltip string
---@field private Section string
---@field private Options table
---@field private Handles table
BlueprintSetting = _Class:Create("BlueprintSetting", nil, {
    Id = "",
    Name = "",
    Type = "",
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
    local name = self.Name
    if self.Handles.NameHandle then
        local translatedName = Ext.Loca.GetTranslatedString(self.Handles.NameHandle)
        if translatedName ~= nil and translatedName ~= "" then
            name = translatedName
        end
    end

    return name
end

function BlueprintSetting:GetId()
    return self.Id
end

function BlueprintSetting:GetType()
    return self.Type
end

function BlueprintSetting:GetDefault()
    return self.Default
end

function BlueprintSetting:GetDescription()
    return self.Description
end

function BlueprintSetting:GetTooltip()
    return self.Tooltip
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
    -- Implement logic to retrieve the current value of the setting
    -- This will likely involve interacting with the Config and MCMAPI classes
    return self.Default
end

--- Set the value of the setting
---@param value any
function BlueprintSetting:SetValue(value)
    -- Implement logic to set the value of the setting
    -- This will likely involve interacting with the Config and MCMAPI classes
end

--- Reset the setting to its default value
function BlueprintSetting:ResetToDefault()
    -- Implement logic to reset the setting to its default value
    -- This will likely involve interacting with the Config and MCMAPI classes
end
