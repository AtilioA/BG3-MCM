-- --[[
--     This file has code adapted from sources originally licensed under the MIT License (JSON loading from CF). The terms of the MIT License are as follows:

--     MIT License

--     Copyright (c) 2023 BG3-Community-Library-Team

--     Permission is hereby granted, free of charge, to any person obtaining a copy
--     of this software and associated documentation files (the "Software"), to deal
--     in the Software without restriction, including without limitation the rights
--     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--     copies of the Software, and to permit persons to whom the Software is
--     furnished to do so, subject to the following conditions:

--     The above copyright notice and this permission notice shall be included in all
--     copies or substantial portions of the Software.

--     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--     SOFTWARE.
-- --]]

---@class MCM: MetaClass
---@field mods table<string, table> A table containing settings data for each mod
MCM = _Class:Create("MCM", nil, {
    mods = {},
})

-- -- NOTE: When introducing new (breaking) versions of the config file, add a new function to parse the new version and update the version number in the config file
-- -- local versionHandlers = {
-- --   [1] = parseVersion1Config,
-- --   [2] = parseVersion2Config,
-- -- }


--- Submit the data to the MCM instance
---@param data table The item data to submit
---@param modGUID string The UUID of the mod that the item data belongs to
function MCM:SubmitData(data, modGUID)
    local preprocessedData = DataPreprocessing:PreprocessData(data, modGUID)
    if not preprocessedData then
        return
    end

    -- ISUtils:InitializeModVarsForMod(preprocessedData, modGUID)
    self.mods[modGUID] = preprocessedData
end

--- Load config files for each mod in the load order, if they exist. The config file should be named "MCMFrameworkConfig.jsonc" and be located in the mod's directory, alongside the mod's meta.lsx file.
function MCM:LoadSettings()
    -- Ensure ModVars table is initialized
    -- self:InitializeModVars()

    -- If only we had `continue` in Lua...
    for _, uuid in pairs(Ext.Mod.GetLoadOrder()) do
        local modData = Ext.Mod.GetMod(uuid)
        ISFDebug(3, "Checking mod: " .. modData.Info.Name)

        local filePath = JsonLayer.ConfigFilePathPatternJSON:format(modData.Info.Directory)
        local config = Ext.IO.LoadFile(filePath, "data")
        if config ~= nil and config ~= "" then
            ISFDebug(2, "Found config for mod: " .. Ext.Mod.GetMod(uuid).Info.Name)
            local data = JsonLayer:TryLoadConfig(config, uuid)
            _D(data)
            if data ~= nil and type(data) == "table" then
                self:SubmitData(data, uuid)
            else
                ISFWarn(0,
                    "Failed to load ISF config JSON file for mod: " ..
                    Ext.Mod.GetMod(uuid).Info.Name ..
                    ". Please contact " .. Ext.Mod.GetMod(uuid).Info.Author .. " about this issue.")
            end
        end
    end
end

-- --- Set the trigger for the shipment, e.g. "ConsoleCommand", "LevelGameplayStarted", "EndTheDayRequested"
-- ---@param trigger string|nil The trigger/reason to set
-- ---@return nil
-- function MCM:SetShipmentTrigger(trigger)
--     self.shipmentTrigger = trigger
-- end

-- --- Set the flag for whether the player has been notified for the current shipment
-- ---@param value boolean The value to set
-- ---@return nil
-- function MCM:SetNotifiedForThisShipment(value)
--     self.hasNotifiedForThisShipment = value
-- end

-- --- Process shipments for a specific mod.
-- ---@param modGUID string The UUID of the mod being processed
-- ---@param skipChecks boolean Whether to skip checking if the item already exists
-- ---@return nil
-- function MCM:ProcessModShipments(modGUID, skipChecks)
--     if not Ext.Mod.IsModLoaded(modGUID) then
--         ISFWarn(1, "Mod " .. modGUID .. " is not loaded, skipping.")
--         return
--     end

--     ISFDebug(1, "Checking items to add from mod " .. Ext.Mod.GetMod(modGUID).Info.Name)
--     for _, item in pairs(MCMInstance.mods[modGUID].Items) do
--         local shouldShipItem = self:ShouldShipItem(modGUID, item)
--         if (skipChecks or shouldShipItem) then
--             self:ShipItem(modGUID, item)
--             -- NOTE: this is not accounting for multiplayer characters/mailboxes, and will likely never be
--             -- FIXME: should actually check if the item has been added, but it's a minor issue
--             ISUtils:NotifyPlayer(item, modGUID)
--         end
--     end
-- end

-- --- Process shipments for each mod that has been loaded.
-- ---@param skipChecks boolean Whether to skip the existence check for the item in inventories, etc. before adding it to the destination
-- ---@return nil
-- function MCM:ProcessShipments(skipChecks)
--     -- Make sure mailboxes are inside chests, if not, move them
--     ISMailboxes:MakeSureMailboxesAreInsideChests()

--     skipChecks = skipChecks or false
--     ISMailboxes:InitializeMailboxes()

--     -- Add a small delay to ensure camp chests are loaded/mailboxes are initialized and that notifications can be read by the player (no faded screen)
--     VCHelpers.Timer:OnTime(2000, function()
--         ISFDebug(2, "Processing shipments for all mods.")

--         -- Iterate through each mod and process shipments
--         for modGUID, modData in pairs(MCMInstance.mods) do
--             self:ProcessModShipments(modGUID, skipChecks)
--         end

--         self:SetShipmentTrigger(nil)
--         self:SetNotifiedForThisShipment(false)
--     end)
-- end

-- --- Check if the item should be shipped based on the item's configuration for trigger checks
-- ---@param item table The item being processed
-- ---@return boolean True if the trigger matches the item's configuration, false otherwise
-- function MCM:IsTriggerCompatible(item)
--     -- Always ship if the trigger is "ConsoleCommand"
--     if self.shipmentTrigger == "ConsoleCommand" then
--         return true
--     end

--     for trigger, shouldShip in pairs(item.Send.On) do
--         if shouldShip and self.shipmentTrigger == trigger then
--             return true
--         end
--     end

--     return false
-- end

-- --- Check if the item should be shipped based on the item's configuration for trigger and existence checks
-- ---@param modGUID string The UUID of the mod being processed
-- ---@param item table The item being processed
-- ---@return boolean True if the item should be shipped, false otherwise
-- function MCM:ShouldShipItem(modGUID, item)
--     local passedProgressionChecks = ISChecks:ProgressionShipmentChecks(item)
--     local IsTriggerCompatible = self:IsTriggerCompatible(item)
--     local itemExists = ISChecks:CheckExistence(modGUID, item)

--     if not passedProgressionChecks then
--         ISFPrint(2,
--             string.format("Item %s (%s) did not pass progression checks.", item.TemplateUUID,
--                 VCHelpers.Loca:GetTranslatedStringFromTemplateUUID(item.TemplateUUID)))
--         return false
--     elseif not IsTriggerCompatible then
--         ISFPrint(2,
--             string.format("Item %s (%s) is not compatible with the current trigger.", item.TemplateUUID,
--                 VCHelpers.Loca:GetTranslatedStringFromTemplateUUID(item.TemplateUUID)))
--         return false
--     elseif itemExists then
--         ISFPrint(2,
--             string.format("Item %s (%s) has been shipped already or exists in inventories or camp chests.",
--                 item.TemplateUUID, VCHelpers.Loca:GetTranslatedStringFromTemplateUUID(item.TemplateUUID)))
--         return false
--     end

--     return true
-- end

-- --- Get the target inventories to receive an item template based on the ISF item's configuration
-- ---@param item table The JSON item being processed
-- ---@return table targetInventories A table containing the UUIDs of objects that should receive the item
-- function MCM:GetTargetInventories(item)
--     local targetInventories = {}

--     -- Check if the item should be sent to the host
--     if item.Send.To.Host then
--         table.insert(targetInventories, Osi.GetHostCharacter())
--     end

--     -- Check each camp chest and add the corresponding mailbox to the targetInventories
--     for chestIndex = 1, 4 do
--         local mailboxUUID = ISMailboxes:GetPlayerMailbox(chestIndex)
--         if mailboxUUID and item.Send.To.CampChest[ISMailboxes.PlayerChestIndexMapping[tostring(chestIndex)]] then
--             ISFDebug(1, "Adding mailbox to delivery list: " .. mailboxUUID)
--             table.insert(targetInventories, mailboxUUID)
--         else
--             ISFDebug(2, "Skipping mailbox for chestIndex: " .. chestIndex)
--         end
--     end

--     return targetInventories
-- end

-- --- Add an item to a table of inventories (objects UUIDs)
-- ---@param modGUID string The UUID of the mod being processed
-- ---@param item table The JSON item table being processed
-- ---@param targetInventories table A table containing the UUIDs of objects that should receive the item
-- function MCM:AddItemToTargetInventories(item, targetInventories)
--     local quantity = item.Send.Quantity or 1
--     ISFDebug(3,
--         "Quantity for item: " ..
--         VCHelpers.Loca:GetTranslatedStringFromTemplateUUID(item.TemplateUUID) .. " is: " .. quantity)

--     local notify = item.Send.NotifyPlayer and 1 or 0

--     for _, targetInventory in ipairs(targetInventories) do
--         if targetInventory ~= nil then
--             ISFPrint(0,
--                 string.format("Adding %d copies of item with UUID: %s (%s) to inventory: %s", quantity, item
--                     .TemplateUUID, VCHelpers.Loca:GetTranslatedStringFromTemplateUUID(item.TemplateUUID),
--                     targetInventory))
--             for i = 1, quantity do
--                 ISFDebug(2, "Adding copy #%s of item to inventory: %s", i, targetInventory)
--                 Osi.TemplateAddTo(item.TemplateUUID, targetInventory, 1, notify)
--             end
--         else
--             ISFPrint(1, "No valid target inventory found for item: " .. item.TemplateUUID)
--         end
--     end
-- end

-- --- Add the item to the target inventory, based on the item's configuration for Send.To
-- ---@param modGUID string The UUID of the mod being processed
-- ---@param item table The item being processed
-- ---@return nil
-- function MCM:ShipItem(modGUID, item)
--     local ISFModVars = Ext.Vars.GetModVariables(ModuleUUID)

--     ISFDebug(1, "About to add item with config: " .. Ext.Json.Stringify(item), { Beautify = true })
--     ISFDebug(2, "Mailboxes: " .. Ext.Json.Stringify(ISFModVars.Mailboxes), { Beautify = true })

--     local targetInventories = self:GetTargetInventories(item)
--     ISFDebug(2, "Target inventories that will receive the item: " .. Ext.Json.Stringify(targetInventories),
--         { Beautify = true })

--     self:AddItemToTargetInventories(item, targetInventories)

--     -- ... Update ... and sync... ModVars to track added items ... 😔
--     ISFModVars.Shipments[modGUID][item.TemplateUUID] = true
--     ISFModVars.Shipments[modGUID][item.TemplateUUID] = ISFModVars.Shipments[modGUID][item.TemplateUUID]
--     VCHelpers.ModVars:Sync(ModuleUUID)
-- end

-- --- Iterate all camp chests and party members inventories to delete all items that are from ISF. These items have ISF_ in their template name.
-- ---@return nil
-- function MCM:DeleteAllISFItems()
--     local campChestUUIDs = VCHelpers.Camp:GetAllCampChestUUIDs()
--     for _, campChestUUID in ipairs(campChestUUIDs) do
--         if campChestUUID then
--             ISFPrint(0, "Deleting all ISF items from camp chest: " .. campChestUUID)
--             ISUtils:DeleteAllISFItemsFromInventory(campChestUUID)
--         end
--     end

--     for _, character in pairs(VCHelpers.Party:GetAllPartyMembers()) do
--         ISFPrint(0, "Deleting all ISF items from character: " .. character)
--         ISUtils:DeleteAllISFItemsFromInventory(character)
--     end
-- end
