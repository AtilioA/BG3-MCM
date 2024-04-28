---@class SchemaSetting
---@field private Id string
---@field private Name string
---@field private Type string
---@field private Default any
---@field private Description string
---@field private Tooltip string
---@field private Section string
---@field private Options table
---@field private Handles table
SchemaSetting = _Class:Create("SchemaSetting", nil, {
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

function SchemaSetting:GetName()
    return self.Name
end

function SchemaSetting:GetId()
    return self.Id
end

function SchemaSetting:GetType()
    return self.Type
end

function SchemaSetting:GetDefault()
    return self.Default
end

function SchemaSetting:GetDescription()
    return self.Description
end

function SchemaSetting:GetTooltip()
    return self.Tooltip
end

function SchemaSetting:GetSection()
    return self.Section
end

function SchemaSetting:GetOptions()
    return self.Options
end

function SchemaSetting:GetHandles()
    return self.Handles
end

function SchemaSetting:SetName(value)
    self.Name = value
end

function SchemaSetting:SetId(value)
    self.Id = value
end

function SchemaSetting:SetType(value)
    self.Type = value
end

function SchemaSetting:SetDefault(value)
    self.Default = value
end

function SchemaSetting:SetDescription(value)
    self.Description = value
end

function SchemaSetting:SetTooltip(value)
    self.Tooltip = value
end

function SchemaSetting:SetSection(value)
    self.Section = value
end

function SchemaSetting:SetOptions(value)
    self.Options = value
end

function SchemaSetting:SetHandles(value)
    self.Handles = value
end

-- --- Create a new SchemaSetting instance
-- ---@param settingData table The setting data from the MCM schema
-- function SchemaSetting:New(settingData)
--     local obj = _Class:New(self)
--     obj:Init(settingData)
--     return obj
-- end

--- Get the current value of the setting
---@return any
function SchemaSetting:GetValue()
    -- Implement logic to retrieve the current value of the setting
    -- This will likely involve interacting with the Config and MCMAPI classes
    return self.Default
end

--- Set the value of the setting
---@param value any
function SchemaSetting:SetValue(value)
    -- Implement logic to set the value of the setting
    -- This will likely involve interacting with the Config and MCMAPI classes
end

--- Reset the setting to its default value
function SchemaSetting:ResetToDefault()
    -- Implement logic to reset the setting to its default value
    -- This will likely involve interacting with the Config and MCMAPI classes
end
