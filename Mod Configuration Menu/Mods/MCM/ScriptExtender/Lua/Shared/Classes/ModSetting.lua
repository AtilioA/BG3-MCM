---@class ModSetting
ModSetting = _Class:Create("ModSetting", {
    Name = "",
    Type = "",
    Default = nil,
    Description = "",
    Section = "General",
    Options = {},
    Min = 0,
    Max = 0
})

--- Create a new ModSetting instance
---@param settingData table The setting data from the MCM schema
function ModSetting:New(settingData)
    local obj = _Class:New(self)
    obj:Init(settingData)
    return obj
end

--- Initialize the ModSetting instance
---@param settingData table The setting data from the MCM schema
function ModSetting:Init(settingData)
    self.Name = settingData.Name
    self.Type = settingData.Type
    self.Default = settingData.Default
    self.Description = settingData.Description
    self.Section = settingData.Section or "General"
    self.Options = settingData.Options or {}
    self.Min = settingData.Min or 0
    self.Max = settingData.Max or 0
end

--- Get the current value of the setting
---@return any
function ModSetting:GetValue()
    -- Implement logic to retrieve the current value of the setting
    -- This will likely involve interacting with the Config and MCMAPI classes
    return self.Default
end

--- Set the value of the setting
---@param value any
function ModSetting:SetValue(value)
    -- Implement logic to set the value of the setting
    -- This will likely involve interacting with the Config and MCMAPI classes
end

--- Reset the setting to its default value
function ModSetting:ResetToDefault()
    -- Implement logic to reset the setting to its default value
    -- This will likely involve interacting with the Config and MCMAPI classes
end
