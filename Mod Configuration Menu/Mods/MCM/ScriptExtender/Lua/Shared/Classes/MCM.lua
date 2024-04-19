---@class MCM: MetaClass
---@field private mods table<string, table> A table of modGUIDs that has a table of schemas and settings for each mod
MCM = _Class:Create("MCM", nil, {
    mods = {},
    profiles = {},
})

-- -- NOTE: When introducing new (breaking) versions of the config file, add a new function to parse the new version and update the version number in the config file
-- -- local versionHandlers = {
-- --   [1] = parseVersion1Config,
-- --   [2] = parseVersion2Config,
-- -- }

function MCM:LoadConfigs()
    self.mods = ModConfig:GetSettings()
    self.profiles = ModConfig:GetProfiles()
    -- FIXME: profiles must be loaded after settings for some janky reason
    self:CreateModMenu()
    -- Ext.Net.BroadcastMessage("MCM_Settings_To_Client", Ext.Json.Stringify({ mods = self.mods, profiles = self.profiles }))
end

--- Create a new MCM profile
---@param profileName string The name of the new profile
function MCM:CreateProfile(profileName)
    ModConfig:CreateProfile(profileName)
end

--- Get the table of MCM profiles
---@return table<string, table> The table of profiles
function MCM:GetProfiles()
    return ModConfig:GetProfiles()
end

--- Get the current MCM profile's name
---@return string The name of the current profile
function MCM:GetCurrentProfile()
    return ModConfig:GetCurrentProfile()
end

--- Set the current MCM profile to the specified profile. This will also update the settings to reflect the new profile settings. If the profile does not exist, it will be created.
---@param profileName string The name of the profile to set as the current profile
---@return boolean success Whether the profile was successfully set
function MCM:SetProfile(profileName)
    return ModConfig:SetCurrentProfile(profileName)
end

-- TODO: Implement profile deletion

--- Get the settings table for a mod
---@param modGUID? string The UUID of the mod. When not provided, the settings for the current mod are returned (ModuleUUID is used)
---@return table<string, table> self.mods[modGUID].settings settings table for the mod
function MCM:GetModSettings(modGUID)
    if modGUID then
        return self.mods[modGUID].settingsValues
    else
        return self.mods[ModuleUUID].settingsValues
    end
end

--- Get the Schema table for a mod
---@param modGUID? string The UUID of the mod. When not provided, the schema for the current mod is returned (ModuleUUID is used)
---@return Schema - The Schema for the mod
function MCM:GetModSchema(modGUID)
    if modGUID then
        return self.mods[modGUID].schemas
    else
        return self.mods[ModuleUUID].schemas
    end
end

--- Get the value of a configuration setting
---@param settingName string The name of the setting
---@param modGUID? GUIDSTRING The UUID of the mod (optional)
---@return any The value of the setting
function MCM:GetConfigValue(settingName, modGUID)
    local modSettingsTable = self:GetModSettings(modGUID)
    if modSettingsTable then
        return modSettingsTable[settingName]
    else
        return nil
    end
end

local InputWidgets = {
    ["int"] = function(group, setting, settingValue, modGUID)
        return IntIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end,
    ["float"] = function(group, setting, settingValue, modGUID)
        return FloatIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end,
    ["checkbox"] = function(group, setting, settingValue, modGUID)
        return CheckboxIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end,
    ["text"] = function(group, setting, settingValue, modGUID)
        return TextIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end,
    ["enum"] = function(group, setting, settingValue, modGUID)
        return EnumIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end,
    ["slider"] = function(group, setting, settingValue, modGUID)
        return SliderIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end,
    ["radio"] = function(group, setting, settingValue, modGUID)
        return RadioIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end,
    ["dict"] = function(group, setting, settingValue, modGUID)
        return DictIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    end
}

function MCM:CreateModMenu()
    -- Add the main tab bar for the mods
    local tabBar = IMGUI_WINDOW:AddTabBar("general")
    self.mod_tabs = {}

    -- Iterate over all mods and create a tab for each
    for modGUID, _ in pairs(self.mods) do
        local modInfo = Ext.Mod.GetMod(modGUID).Info
        local modSchema = self:GetModSchema(modGUID)
        local modSettings = self:GetModSettings(modGUID)
        local modTab = tabBar:AddTabItem(modInfo.Name)

        -- Save reference to the mod tab
        self.mod_tabs[modGUID] = modTab

        -- Create a new IMGUI group for each mod to hold all settings
        local modGroup = modTab:AddGroup(modInfo.Name .. "_GROUP")
        _D(modSchema)
        -- Iterate over each section in the mod schema
        for _, section in ipairs(modSchema:GetSections()) do
            _D(section)
            modGroup:AddTabBar(section.SectionName)
            -- Iterate over each setting in the section
            for _, setting in pairs(section:GetSettings()) do
                local settingValue = modSettings[setting.Id]
                local createWidget = InputWidgets[setting:GetType()]
                createWidget(modGroup, setting, settingValue, modGUID)
            end
        end
    end
end

--- Set the value of a configuration setting
---@param settingName string The name of the setting
---@param value any The new value of the setting
---@param modGUID? GUIDSTRING The UUID of the mod (optional)
function MCM:SetConfigValue(settingName, value, modGUID)
    modGUID = modGUID or ModuleUUID

    local modSettingsTable = self:GetModSettings(modGUID)

    modSettingsTable[settingName] = value
    ModConfig:UpdateAllSettingsForMod(modGUID, modSettingsTable)
end

---@param settingName string The name of the setting to reset
---@param modGUID? GUIDSTRING The UUID of the mod (optional)
function MCM:ResetConfigValue(settingName, modGUID)
    modGUID = modGUID or ModuleUUID

    local schema = self:GetModSchema(modGUID)

    local defaultValue = schema:RetrieveDefaultValueForSetting(settingName)
    if defaultValue == nil then
        MCMWarn(1, "Setting '" .. settingName .. "' not found in the schema for mod '" .. modGUID .. "'.")
    else
        self:SetConfigValue(settingName, defaultValue, modGUID)
    end
end

--- Reset all settings for a mod to their default values
---@param modGUID? GUIDSTRING The UUID of the mod. When not provided, the settings for the current mod are reset (ModuleUUID is used)
function MCM:ResetAllSettings(modGUID)
    local modSchema = self.schemas[modGUID]
    local defaultSettings = Schema:GetDefaultSettingsFromSchema(modSchema)

    ModConfig:UpdateAllSettingsForMod(modGUID, defaultSettings)
end

-- TODO:
-- --- Reset all settings from a section to their default values
-- ---@param sectionName string The name of the section
-- ---@param modGUID? GUIDSTRING The UUID of the mod. When not provided, the settings for the current mod are reset (ModuleUUID is used)
-- function MCM:ResetSectionValues(sectionName, modGUID)
--     local modSchema = self.schemas[modGUID]
--     local defaultSettings = Schema:GetDefaultSettingsFromSchema(modSchema)
--     local modSettings = self.settings[modGUID]
-- end
