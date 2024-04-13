-- ---@class HelperISDataPreprocessing: Helper
-- ISDataPreprocessing = _Class:Create("HelperISDataPreprocessing", Helper)

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

-- --- Remove elements in the table that do not have a FileVersions, Items table, and any elements in the Items table that do not have a TemplateUUID
-- ---@param data table The item data to sanitize
-- function ISDataPreprocessing:SanitizeData(data, modGUID)
--     if not self:HasFileVersionsEntry(data, modGUID) then
--         return
--     end

--     if not self:HasItemsTable(data, modGUID) then
--         return
--     end

--     self:RemoveItemsWithoutTemplateUUID(data, modGUID)

--     -- Turn string booleans into actual booleans
--     convertStringBooleans(data)

--     return data
-- end

-- --- Check if the data table has a FileVersions table
-- ---@param data table The item data to check
-- ---@param modGUID string The UUID of the mod being processed
-- ---@return boolean True if the data table has a FileVersions table, false otherwise
-- function ISDataPreprocessing:HasFileVersionsEntry(data, modGUID)
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
-- function ISDataPreprocessing:HasItemsTable(data, modGUID)
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
-- function ISDataPreprocessing:RemoveItemsWithoutTemplateUUID(data, modGUID)
--     for i = #data.Items, 1, -1 do
--         if not self:IsValidItemTemplateUUID(data.Items[i], modGUID) then
--             table.remove(data.Items, i)
--         end
--     end
-- end

-- --- Check if the item has a valid TemplateUUID
-- ---@param item table The item being processed
-- ---@param modGUID string The UUID of the mod being processed
-- ---@return boolean True if the item has a valid TemplateUUID, false otherwise
-- function ISDataPreprocessing:IsValidItemTemplateUUID(item, modGUID)
--     local itemTemplateUUID = item.TemplateUUID
--     if not itemTemplateUUID then
--         ISFWarn(0,
--             "ISF config file for mod " ..
--             Ext.Mod.GetMod(modGUID).Info.Name ..
--             " contains an item entry that does not have a TemplateUUID and will be ignored. Please contact " ..
--             Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
--         return false
--     end

--     local success, result = pcall(function()
--         if VCHelpers.Template:HasTemplate(itemTemplateUUID) ~= true then
--             ISFWarn(0,
--                 "ISF config file for mod " ..
--                 Ext.Mod.GetMod(modGUID).Info.Name ..
--                 " contains an item entry with a TemplateUUID ('" ..
--                 itemTemplateUUID .. "') that does not exist in the game and will be ignored. Please contact " ..
--                 Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
--             return false
--         else
--             return true
--         end
--     end)

--     if not result then
--         return false
--     end

--     if not success then
--         ISFWarn(0,
--             "ISF config file produced an error while checking the item '" ..
--             itemTemplateUUID .. "'. Error: " ..
--             result ..
--             ". For mod " ..
--             Ext.Mod.GetMod(modGUID).Info.Name ..
--             ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
--         return false
--     end

--     return true
-- end

-- --- ApplyDefaultValues ensures that any missing fields in the JSON data are assigned default values.
-- ---@param data table The item data to process
-- function ISDataPreprocessing:ApplyDefaultValues(data)
--     for _, item in ipairs(data.Items) do
--         -- Set default value for Send
--         item.Send = item.Send or {}
--         -- Set default value for Send.Quantity
--         if item.Send.Quantity == nil or item.Send.Quantity < 0 then
--             item.Send.Quantity = 1
--         end

--         -- Set default values for Send.To
--         item.Send.To = item.Send.To or {}
--         if item.Send.To.Host == nil then
--             item.Send.To.Host = false
--         end

--         item.Send.To.CampChest = item.Send.To.CampChest or {}
--         if item.Send.To.CampChest.Player1Chest == nil then
--             item.Send.To.CampChest.Player1Chest = true
--         end
--         if item.Send.To.CampChest.Player2Chest == nil then
--             item.Send.To.CampChest.Player2Chest = true
--         end
--         if item.Send.To.CampChest.Player3Chest == nil then
--             item.Send.To.CampChest.Player3Chest = true
--         end
--         if item.Send.To.CampChest.Player4Chest == nil then
--             item.Send.To.CampChest.Player4Chest = true
--         end

--         -- Set default values for Send.On
--         item.Send.On = item.Send.On or {}
--         if item.Send.On.SaveLoad == nil then
--             item.Send.On.SaveLoad = true
--         end
--         if item.Send.On.DayEnd == nil then
--             item.Send.On.DayEnd = false
--         end

--         -- Set default value for Send.NotifyPlayer
--         if item.Send.NotifyPlayer == nil then
--             item.Send.NotifyPlayer = true
--         end

--         -- Set default values for Send.Check
--         item.Send.Check = item.Send.Check or {}

--         -- Set default values for Send.Check.ItemExistence
--         item.Send.Check.ItemExistence = item.Send.Check.ItemExistence or {}
--         item.Send.Check.ItemExistence.CampChest = item.Send.Check.ItemExistence.CampChest or {}
--         if item.Send.Check.ItemExistence.CampChest.Player1Chest == nil then
--             item.Send.Check.ItemExistence.CampChest.Player1Chest = true
--         end
--         if item.Send.Check.ItemExistence.CampChest.Player2Chest == nil then
--             item.Send.Check.ItemExistence.CampChest.Player2Chest = true
--         end
--         if item.Send.Check.ItemExistence.CampChest.Player3Chest == nil then
--             item.Send.Check.ItemExistence.CampChest.Player3Chest = true
--         end
--         if item.Send.Check.ItemExistence.CampChest.Player4Chest == nil then
--             item.Send.Check.ItemExistence.CampChest.Player4Chest = true
--         end

--         item.Send.Check.ItemExistence.PartyMembers = item.Send.Check.ItemExistence.PartyMembers or {}
--         if item.Send.Check.ItemExistence.PartyMembers.AtCamp == nil then
--             item.Send.Check.ItemExistence.PartyMembers.AtCamp = true
--         end
--         if item.Send.Check.ItemExistence.FrameworkCheck == nil then
--             item.Send.Check.ItemExistence.FrameworkCheck = true
--         end

--         if item.Send.Check.ItemExistence.FrameworkCheck == nil then
--             item.Send.Check.ItemExistence.FrameworkCheck = true
--         end

--         -- Set default values for Send.Check.PlayerProgression
--         item.Send.Check.PlayerProgression = item.Send.Check.PlayerProgression or {}
--         if item.Send.Check.PlayerProgression.Act == nil then
--             item.Send.Check.PlayerProgression.Act = 1
--         end
--         if item.Send.Check.PlayerProgression.Level == nil then
--             item.Send.Check.PlayerProgression.Level = 1
--         end
--     end

--     return data
-- end

-- --- PreprocessData is a wrapper function that calls the SanitizeData and ApplyDefaultValues functions.
-- ---@param data table The item data to process
-- ---@param modGUID string The GUID of the mod that the data belongs to
-- ---@return table|nil The processed item data, or nil if the data could not be processed (e.g. if it failed sanitization due to invalid data)
-- function ISDataPreprocessing:PreprocessData(data, modGUID)
--     local sanitizedData = self:SanitizeData(data, modGUID)
--     if not sanitizedData then
--         ISFWarn(0,
--             "Failed to sanitize ISF config JSON data for mod: " ..
--             Ext.Mod.GetMod(modGUID).Info.Name ..
--             ". Please contact " .. Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
--         return
--     end

--     return self:ApplyDefaultValues(data)
-- end
