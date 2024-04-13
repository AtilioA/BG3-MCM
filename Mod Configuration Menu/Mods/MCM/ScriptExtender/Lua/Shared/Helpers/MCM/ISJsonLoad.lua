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

---@class HelperISJsonLoad: Helper
ISJsonLoad = _Class:Create("HelperISJsonLoad", Helper)

-- Patterns for the potential JSON and JSONc config file paths to be loaded
ISJsonLoad.ConfigFilePathPatternJSON = string.gsub("Mods/%s/MCM_schema.json", "'", "\'")

--- Load the JSON file for the mod and submit the data to the ItemShipment instance
---@param configStr string The string representation of the JSONc file
---@param modGUID GUIDSTRING The UUID of the mod that the config file belongs to
function ISJsonLoad:TryLoadConfig(configStr, modGUID)
    if modGUID == nil then
        ISFWarn(1, "modGUID is nil. Cannot load config.")
        return
    end

    ISFDebug(2, "Entering TryLoadConfig with parameters: " .. configStr .. ", " .. modGUID)

    local success, data = pcall(Ext.Json.Parse, configStr)
    if success then
        return data
    else
        ISFWarn(0,
            "Invalid ISF config JSON file for mod " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " for assistance.")
        return
    end
end
