---@class SchemaSetting
---@field private Name string
---@field private Type string
---@field private Default any
---@field private Description string
---@field private Section string
---@field private Options table
SchemaSetting = _Class:Create("SchemaSetting", nil, {
    Name = "",
    Type = "",
    Default = nil,
    Description = "",
    Section = "General",
    Options = {}
})

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
