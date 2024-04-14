--[[
    This file has code adapted from sources originally licensed under the MIT License. The terms of the MIT License are as follows:

    MIT License

    Copyright (c) 2023 BG3-Community-Library-Team

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
--]]

---@class HelperJsonLayer: Helper
JsonLayer = _Class:Create("HelperJsonLayer", Helper, {
    settings_index = {}
})

-- Patterns for the potential JSON and JSONc config file paths to be loaded
JsonLayer.ConfigFilePathPatternJSON = string.gsub("Mods/%s/MCM_schema.json", "'", "\'")

--- Load the JSON file for the mod and build the settings index
---@param configStr string The string representation of the JSONc file
---@param modGUID GUIDSTRING The UUID of the mod that the config file belongs to
---@return table|nil The parsed JSON data, or nil if the JSON could not be parsed
function JsonLayer:TryLoadConfig(configStr, modGUID)
    if modGUID == nil then
        ISFWarn(1, "modGUID is nil. Cannot load config.")
        return nil
    end

    ISFDebug(2, "Entering TryLoadConfig with parameters: " .. configStr .. ", " .. modGUID)

    local success, data = pcall(Ext.Json.Parse, configStr)
    if success then
        self:BuildSettingsIndex(data)
        _D(self.settings_index)
        return data
    else
        ISFWarn(0,
            "Invalid ISF config JSON file for mod " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " for assistance.")
        return nil
    end
end

--- Build an index for direct setting access
---@param data table
function JsonLayer:BuildSettingsIndex(data)
    self.settings_index = {}
    if data.Sections then
        for _, section in ipairs(data.Sections) do
            for _, setting in ipairs(section.Settings) do
                self.settings_index[setting.Name] = {
                    section = section.SectionName,
                    setting = setting
                }
            end
        end
    end
end

--- Get a setting by name
---@param settingName string
---@return table
function JsonLayer:GetSetting(settingName)
    local setting = self.settings_index[settingName]
    if setting then
        return setting.setting
    else
        ISFWarn(1, "Setting " .. settingName .. " not found.")
        return nil
    end
end

--- Update a setting by name
---@param settingName string
---@param newValue any
function JsonLayer:UpdateSetting(settingName, newValue)
    local setting = self:GetSetting(settingName)
    if setting then
        setting.Default = newValue
        ISFDebug(3, "Updated " .. settingName .. " to " .. tostring(newValue))
    end
end
