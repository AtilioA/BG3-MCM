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

--- Remove elements in the table that do not have a FileVersions, Items table, and any elements in the Items table that do not have a TemplateUUID
---@param data table The item data to sanitize
function DataPreprocessing:SanitizeData(data, modGUID)
    return {}
    -- if not self:HasFileVersionsEntry(data, modGUID) then
    --     return
    -- end

    -- if not self:HasItemsTable(data, modGUID) then
    --     return
    -- end

    -- self:RemoveItemsWithoutTemplateUUID(data, modGUID)

    -- -- Turn string booleans into actual booleans
    -- convertStringBooleans(data)
end

-- --- Check if the data table has a FileVersions table
-- ---@param data table The item data to check
-- ---@param modGUID string The UUID of the mod being processed
-- ---@return boolean True if the data table has a FileVersions table, false otherwise
-- function DataPreprocessing:HasFileVersionsEntry(data, modGUID)
--     if not data.FileVersion then
--         ISFWarn(0,
--             "No 'FileVersion' section found in data for mod: " ..
--             Ext.Mod.GetMod(modGUID).Info.Name ..
--             ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
--         return false
--     elseif type(data.FileVersion) ~= "number" then
--         ISFWarn(0,
--             "Invalid 'FileVersion' section (not a number) found in data for mod: " ..
--             Ext.Mod.GetMod(modGUID).Info.Name ..
--             ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
--         return false
--     end

--     return true
-- end

-- --- Check if the data table has an Items table
-- ---@param data table The item data to check
-- ---@param modGUID string The UUID of the mod being processed
-- ---@return boolean True if the data table has an Items table, false otherwise
-- function DataPreprocessing:HasItemsTable(data, modGUID)
--     if not data.Items then
--         ISFWarn(0,
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

--- PreprocessData is a wrapper function that calls the SanitizeData and ApplyDefaultValues functions.
---@param data table The item data to process
---@param modGUID string The GUID of the mod that the data belongs to
---@return table|nil The processed item data, or nil if the data could not be processed (e.g. if it failed sanitization due to invalid data)
function DataPreprocessing:PreprocessData(data, modGUID)
    local sanitizedData = self:SanitizeData(data, modGUID)
    if not sanitizedData then
        ISFWarn(0,
            "Failed to sanitize ISF config JSON data for mod: " ..
            Ext.Mod.GetMod(modGUID).Info.Name ..
            ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        return
    end
    -- return sanitizedData

    -- return self:ApplyDefaultValues(data)
end
