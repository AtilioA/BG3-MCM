---@class HelperDataPreprocessing: Helper
DataPreprocessing = _Class:Create("HelperDataPreprocessing", Helper)

-- -- Function to convert string booleans to actual booleans
-- local function convertStringBooleans(table)
--     for key, value in pairs(table) do
--         if type(value) == "table" then
--             -- Recursively convert nested tables
--             convertStringBooleans(value)
--         elseif value == "true" then
--             table[key] = true
--         elseif value == "false" then
--             table[key] = false
--         end
--     end
-- end

--- Remove elements in the table that do not have a SchemaVersions, Items table, and any elements in the Items table that do not have a TemplateUUID
---@param data table The item data to sanitize
function DataPreprocessing:SanitizeData(data, modGUID)
    if not self:HasSchemaVersionsEntry(data, modGUID) then
        return
    end

    if not self:HasSectionsEntry(data, modGUID) then
        return
    end

    -- self:RemoveItemsWithoutTemplateUUID(data, modGUID)

    -- Turn string booleans into actual booleans
    -- convertStringBooleans(data)
end

--- Check if the data table has a SchemaVersions table
---@param data table The item data to check
---@param modGUID string The UUID of the mod being processed
---@return boolean True if the data table has a SchemaVersions table, false otherwise
function DataPreprocessing:HasSchemaVersionsEntry(data, modGUID)
    if not data.SchemaVersion then
        MCMWarn(0,
            "No 'SchemaVersion' section found in data for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return false
    elseif type(data.SchemaVersion) ~= "number" then
        MCMWarn(0,
            "Invalid 'SchemaVersion' section (not a number) found in data for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return false
    end

    return true
end

--- Check if the data table has a Sections table
---@param data table The item data to check
---@param modGUID string The UUID of the mod being processed
---@return boolean True if the data table has a Sections table, false otherwise
function DataPreprocessing:HasSectionsEntry(data, modGUID)
    if not data.Sections then
        MCMWarn(0,
            "No 'Sections' section found in data for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return false
    end

    return true
end

-- --- Check if the data table has an Items table
-- ---@param data table The item data to check
-- ---@param modGUID string The UUID of the mod being processed
-- ---@return boolean True if the data table has an Items table, false otherwise
-- function DataPreprocessing:HasItemsTable(data, modGUID)
--     if not data.Items then
--         MCMWarn(0,
--             "No 'Items' section found in data for mod: " ..
--             Ext.Mod.GetMod(modGUID).Info.Name ..
--             ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
--         return false
--     end

--     return true
-- end

-- --- Remove any elements in the Items table that do not have a TemplateUUID
-- ---@param data table The item data to sanitize
-- ---@param modGUID string The UUID of the mod being processed
-- function DataPreprocessing:RemoveItemsWithoutTemplateUUID(data, modGUID)
--     for i = #data.Items, 1, -1 do
--         if not self:IsValidItemTemplateUUID(data.Items[i], modGUID) then
--             table.remove(data.Items, i)
--         end
--     end
-- end

-- --- ApplyDefaultValues ensures that any missing fields in the JSON data are assigned default values.
-- ---@param data table The item data to process
-- function DataPreprocessing:ApplyDefaultValues(data)
--     for _, item in ipairs(data.Items) do
--     end

--     return data
-- end


--- Preprocess the data and create SchemaSetting instances
---@param data table The item data to preprocess
---@param modGUID string The UUID of the mod that the item data belongs to
---@return table<string, SchemaSetting>|nil The preprocessed data, or nil if the preprocessing failed
function DataPreprocessing:PreprocessData(data, modGUID)
    local preprocessedData = data
    for i, section in ipairs(data.Sections) do
        for j, setting in ipairs(section.Settings) do
            local setting = SchemaSetting:New({
                Name = setting.Name,
                Type = setting.Type,
                Default = setting.Default,
                Description = setting.Description,
                Section = setting.Section or "General",
                Options = setting.Options or {}
            })
            preprocessedData["Sections"][i]["Settings"][j] = setting
        end
    end

    return preprocessedData
end

-- --- PreprocessData is a wrapper function that calls the SanitizeData and ApplyDefaultValues functions.
-- ---@param data table The item data to process
-- ---@param modGUID string The GUID of the mod that the data belongs to
-- ---@return table|nil The processed item data, or nil if the data could not be processed (e.g. if it failed sanitization due to invalid data)
-- function DataPreprocessing:PreprocessData(data, modGUID)
--     local sanitizedData = self:SanitizeData(data, modGUID)
--     if not sanitizedData then
--         MCMWarn(0,
--             "Failed to sanitize MCM config JSON data for mod: " ..
--             Ext.Mod.GetMod(modGUID).Info.Name ..
--             ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
--         return
--     end
--     -- return sanitizedData

--     -- return self:ApplyDefaultValues(data)
-- end
