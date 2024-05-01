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

--- The JsonLayer class is a helper class that provides functionality for loading and saving JSON files.
-- It is used throughout MCM to manage the loading and saving of mod configuration settings in a standardized way and isolate the details of working with JSON files.
--
-- The main responsibilities of the JsonLayer class are:
-- - Loading JSON configuration files from a specified file path
-- - Parsing the JSON data and returning it as a Lua table
-- - Saving Lua tables as JSON configuration files
-- - Trying to load a JSON configuration file for a specific mod, handling errors and providing feedback to the user
---@class JsonLayer
JsonLayer = _Class:Create("JsonLayer", nil, {
})

-- Pattern for the potential JSON blueprint file paths to be loaded
JsonLayer.ConfigFilePathPatternJSON = string.gsub("Mods/%s/MCM_blueprint.json", "'", "\'")

---Loads a JSON file from the specified file path.
---@param filePath string The file path of the JSON file to load.
---@return table|nil data The parsed JSON data, or nil if the file could not be loaded or parsed.
function JsonLayer:LoadJSONFile(filePath)
    local fileContent = Ext.IO.LoadFile(filePath)
    if not fileContent or fileContent == "" then
        MCMDebug(2, "Config file not found: " .. filePath)
        return nil
    end

    local success, data = pcall(Ext.Json.Parse, fileContent)
    if not success then
        MCMWarn(0, "Failed to parse config file: " .. filePath)
        return nil
    end

    return data
end

--- Saves the given content to a JSON file.
--- @param filePath string The file path to save the content to.
--- @param content table The table with content to save to the file.
function JsonLayer:SaveJSONFile(filePath, content)
    local fileContent = Ext.Json.Stringify(content, { Beautify = true })
    Ext.IO.SaveFile(filePath, fileContent)
end

--- Parse the JSON file for the mod
---@param configStr string The string representation of the JSON file (to be parsed)
---@param modGUID GUIDSTRING The UUID of the mod that the config file belongs to
---@return table|nil data The parsed JSON data, or nil if the JSON could not be parsed
function JsonLayer:TryParseModJSON(configStr, modGUID)
    if modGUID == nil then
        MCMWarn(1, "modGUID is nil. Cannot load config.")
        return nil
    end

    MCMDebug(4, "Entering TryParseModJSON with parameters: " .. configStr .. ", " .. modGUID)

    local success, data = pcall(Ext.Json.Parse, configStr)
    if success then
        return data
    else
        MCMWarn(0,
            "Invalid MCM config JSON file for mod " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " for assistance.")
        return nil
    end
end

-- Custom exception for file-related issues
function JsonLayer:FileNotFoundError(message)
    error({ code = "FileNotFoundError", message = message })
end

function JsonLayer:JSONParseError(message)
    error({ code = "JSONParseError", message = message })
end

--- Load settings files for each mod in the load order, if they exist. The settings file should be named "MCM_blueprint.json" and be located in the mod's directory, alongside the mod's meta.lsx file.
--- If the file is found, the data is submitted to the ModConfig instance.
--- If the file is not found, a warning is logged. If the file is found but cannot be parsed, an error is logged.
---@param modData table
---@return table|nil data The blueprint data, or an error message if the blueprint could not be loaded
function JsonLayer:LoadBlueprintForMod(modData)
    local blueprintFilepath = self.ConfigFilePathPatternJSON:format(modData.Info.Directory)
    -- REFACTOR: use LoadJSONFile instead, but it's not working for some reason
    local config = Ext.IO.LoadFile(blueprintFilepath, "data")
    if config == nil or config == "" then
        return self:FileNotFoundError("Config file not found for mod: " .. modData.Info.Name)
    end

    local data = self:TryParseModJSON(config, modData.Info.ModuleUUID)
    if data == nil or type(data) ~= "table" then
        return self:JSONParseError("Failed to load MCM blueprint JSON file for mod: " ..
            modData.Info.Name .. ". Please contact " .. modData.Info.Author .. " about this issue.")
    end

    return data
end

--- Flatten the settings table into a single table with the setting ID as the key
---@param settings table The settings table to flatten
---@return table flattenedSettings flattened settings table
function JsonLayer:FlattenSettingsJSON(settings)
    local flatJson = {}

    -- Function to recursively flatten the table
    local function flattenTable(tbl)
        for key, value in pairs(tbl) do
            if type(value) == "table" and not table.isArray(value) then
                -- If the value is a table, recurse
                flattenTable(value)
            else
                -- If the value is not a table, add it to the flat table
                flatJson[key] = value
            end
        end
    end

    -- Start the flattening process from the root
    flattenTable(settings)

    return flatJson
end
