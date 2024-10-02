--[[
    This file has code adapted from Compatibilty Framework sources originally licensed under the MIT License. The terms of the MIT License are as follows:

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
JsonLayer.MCMBlueprintPathPattern = string.gsub("Mods/%s/MCM_blueprint.json", "'", "\'")

---Loads a JSON file from the specified file path.
---@param filePath string The file path of the JSON file to load.
---@return table|nil data The parsed JSON data, or nil if the file could not be loaded or parsed.
function JsonLayer:LoadJSONFile(filePath)
    local fileContent = Ext.IO.LoadFile(filePath)
    if not fileContent or fileContent == "" then
        MCMDebug(2, "JSON file not found: " .. filePath)
        return nil
    end

    local success, data = pcall(Ext.Json.Parse, fileContent)
    if not success then
        MCMWarn(0, "Failed to parse JSON file: " .. filePath)
        return nil
    end

    return data
end

--- Saves the given content to a JSON file.
--- @param filePath string The file path to save the content to.
--- @param content table The table with content to save to the file.
function JsonLayer:SaveJSONFile(filePath, content)
    local fileContent = Ext.Json.Stringify(content)
    Ext.IO.SaveFile(filePath, fileContent)
end

--- Parse the JSON file for the mod
---@param blueprintJSONStr string The string representation of the JSON file (to be parsed)
---@param modUUID GUIDSTRING The UUID of the mod that the blueprint file belongs to
---@return table|nil data The parsed JSON data, or nil if the JSON could not be parsed
function JsonLayer:TryParseModBlueprintJSON(blueprintJSONStr, modUUID)
    if modUUID == nil then
        MCMWarn(1, "modUUID is nil. Cannot load config.")
        return nil
    end

    MCMDebug(4, "Entering TryParseModBlueprintJSON with parameters: " .. blueprintJSONStr .. ", " .. modUUID)

    local success, data = pcall(Ext.Json.Parse, blueprintJSONStr)
    if success then
        return data
    else
        MCMWarn(0,
            "Invalid MCM Blueprint JSON file for mod " ..
            Ext.Mod.GetMod(modUUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modUUID).Info.Author .. " for assistance.")
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
    if modData == nil or modData.Info == nil or modData.Info.Directory == nil then
        return self:FileNotFoundError("Invalid mod meta.lsx file data. Cannot load into MCM.")
    end

    local function checkIncorrectBlueprintPath(modData)
        local SEMCMBlueprintPathPattern = string.gsub("Mods/%s/ScriptExtender/MCM_blueprint.json", "'", "\'")
        local incorrectBlueprintFilepath = SEMCMBlueprintPathPattern:format(modData.Info.Directory)
        local incorrectConfig = self:LoadJSONFile(incorrectBlueprintFilepath)
        if incorrectConfig ~= nil then
            MCMWarn(0,
                string.format(
                    "MCM_blueprint.json found in incorrect location for mod %s. Please move it alongside the mod's meta.lsx file.",
                    modData.Info.Name))
        end
    end

    checkIncorrectBlueprintPath(modData)

    -- REVIEW: use LoadJSONFile instead, but it's not working for some reason
    local blueprintFilepath = self.MCMBlueprintPathPattern:format(modData.Info.Directory)
    local config = Ext.IO.LoadFile(blueprintFilepath, "data")
    if config == nil or config == "" then
        return self:FileNotFoundError("Blueprint file not found for mod: " .. modData.Info.Name)
    end

    local data = self:TryParseModBlueprintJSON(config, modData.Info.ModuleUUID)
    if data == nil or type(data) ~= "table" then
        return self:JSONParseError("Failed to load MCM blueprint JSON file for mod: " ..
            modData.Info.Name ..
            ". Blueprint is present but malformed. Please contact " .. modData.Info.Author .. " about this issue.")
    end

    return data
end

--- REFACTOR: Flattening the settings table is not a good idea, and this could create issues with more arbitrary settings structures (in the future). A tree structure should probably solve this issue while not relying on a flat associative array.
--- Flatten the settings table into a single table with the setting ID as the key
---@param settings table The settings table to flatten
---@param shouldPreserveFunction function A predicate function that determines whether to preserve a table
---@return table flattenedSettings Flattened settings table
function JsonLayer:FlattenSettingsJSON(settings, shouldPreserveFunction)
    local flatJson = {}

    -- Function to recursively flatten the table
    local function flattenTable(tbl)
        for key, value in pairs(tbl) do
            if type(value) == "table" then
                if shouldPreserveFunction and shouldPreserveFunction(key, value) then
                    -- Preserve the table as a separate top-level key
                    flatJson[key] = value
                else
                    -- Recurse into nested tables
                    flattenTable(value)
                end
            else
                -- Assign non-table values directly
                flatJson[key] = value
            end
        end
    end

    -- Start the flattening process from the root
    flattenTable(settings)

    return flatJson
end
