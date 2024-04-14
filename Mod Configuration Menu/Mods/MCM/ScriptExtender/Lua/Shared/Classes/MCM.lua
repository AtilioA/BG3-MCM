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

-- --- Process shipments for a specific mod.
-- ---@param modGUID string The UUID of the mod being processed
-- ---@param skipChecks boolean Whether to skip checking if the item already exists
-- ---@return nil
-- function MCM:ProcessModShipments(modGUID, skipChecks)
--     if not Ext.Mod.IsModLoaded(modGUID) then
--         MCMWarn(1, "Mod " .. modGUID .. " is not loaded, skipping.")
--         return
--     end

--     MCMDebug(1, "Checking items to add from mod " .. Ext.Mod.GetMod(modGUID).Info.Name)
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

function MCM:LoadConfigs()
    ModConfig:LoadData()
end

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
--         MCMDebug(2, "Processing shipments for all mods.")

--         -- Iterate through each mod and process shipments
--         for modGUID, modData in pairs(MCMInstance.mods) do
--             self:ProcessModShipments(modGUID, skipChecks)
--         end

--         self:SetShipmentTrigger(nil)
--         self:SetNotifiedForThisShipment(false)
--     end)
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
--         MCMPrint(2,
--             string.format("Item %s (%s) did not pass progression checks.", item.TemplateUUID,
--                 VCHelpers.Loca:GetTranslatedStringFromTemplateUUID(item.TemplateUUID)))
--         return false
--     elseif not IsTriggerCompatible then
--         MCMPrint(2,
--             string.format("Item %s (%s) is not compatible with the current trigger.", item.TemplateUUID,
--                 VCHelpers.Loca:GetTranslatedStringFromTemplateUUID(item.TemplateUUID)))
--         return false
--     elseif itemExists then
--         MCMPrint(2,
--             string.format("Item %s (%s) has been shipped already or exists in inventories or camp chests.",
--                 item.TemplateUUID, VCHelpers.Loca:GetTranslatedStringFromTemplateUUID(item.TemplateUUID)))
--         return false
--     end

--     return true
-- end

-- --- Get the target inventories to receive an item template based on the MCM item's configuration
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
--             MCMDebug(1, "Adding mailbox to delivery list: " .. mailboxUUID)
--             table.insert(targetInventories, mailboxUUID)
--         else
--             MCMDebug(2, "Skipping mailbox for chestIndex: " .. chestIndex)
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
--     MCMDebug(3,
--         "Quantity for item: " ..
--         VCHelpers.Loca:GetTranslatedStringFromTemplateUUID(item.TemplateUUID) .. " is: " .. quantity)

--     local notify = item.Send.NotifyPlayer and 1 or 0

--     for _, targetInventory in ipairs(targetInventories) do
--         if targetInventory ~= nil then
--             MCMPrint(0,
--                 string.format("Adding %d copies of item with UUID: %s (%s) to inventory: %s", quantity, item
--                     .TemplateUUID, VCHelpers.Loca:GetTranslatedStringFromTemplateUUID(item.TemplateUUID),
--                     targetInventory))
--             for i = 1, quantity do
--                 MCMDebug(2, "Adding copy #%s of item to inventory: %s", i, targetInventory)
--                 Osi.TemplateAddTo(item.TemplateUUID, targetInventory, 1, notify)
--             end
--         else
--             MCMPrint(1, "No valid target inventory found for item: " .. item.TemplateUUID)
--         end
--     end
-- end

-- --- Add the item to the target inventory, based on the item's configuration for Send.To
-- ---@param modGUID string The UUID of the mod being processed
-- ---@param item table The item being processed
-- ---@return nil
-- function MCM:ShipItem(modGUID, item)
--     local MCMModVars = Ext.Vars.GetModVariables(ModuleUUID)

--     MCMDebug(1, "About to add item with config: " .. Ext.Json.Stringify(item), { Beautify = true })
--     MCMDebug(2, "Mailboxes: " .. Ext.Json.Stringify(MCMModVars.Mailboxes), { Beautify = true })

--     local targetInventories = self:GetTargetInventories(item)
--     MCMDebug(2, "Target inventories that will receive the item: " .. Ext.Json.Stringify(targetInventories),
--         { Beautify = true })

--     self:AddItemToTargetInventories(item, targetInventories)

--     -- ... Update ... and sync... ModVars to track added items ... 😔
--     MCMModVars.Shipments[modGUID][item.TemplateUUID] = true
--     MCMModVars.Shipments[modGUID][item.TemplateUUID] = MCMModVars.Shipments[modGUID][item.TemplateUUID]
--     VCHelpers.ModVars:Sync(ModuleUUID)
-- end

-- --- Iterate all camp chests and party members inventories to delete all items that are from MCM. These items have MCM_ in their template name.
-- ---@return nil
-- function MCM:DeleteAllMCMItems()
--     local campChestUUIDs = VCHelpers.Camp:GetAllCampChestUUIDs()
--     for _, campChestUUID in ipairs(campChestUUIDs) do
--         if campChestUUID then
--             MCMPrint(0, "Deleting all MCM items from camp chest: " .. campChestUUID)
--             ISUtils:DeleteAllMCMItemsFromInventory(campChestUUID)
--         end
--     end

--     for _, character in pairs(VCHelpers.Party:GetAllPartyMembers()) do
--         MCMPrint(0, "Deleting all MCM items from character: " .. character)
--         ISUtils:DeleteAllMCMItemsFromInventory(character)
--     end
-- end
