-- ---@class HelperISUtils: Helper
-- ISUtils = _Class:Create("HelperISUtils", Helper)

-- --- Initialize the Shipments table for the given mod
-- ---@param modGUID string The UUID of the mod that the item data belongs to
-- function ISUtils:InitializeShipmentsTable(modGUID)
--     local ISFModVars = Ext.Vars.GetModVariables(ModuleUUID)

--     -- Initialize Shipments table
--     if not ISFModVars.Shipments then
--         ISFModVars.Shipments = {}
--     end
--     -- Initialize the modGUID key in the Shipments table
--     if not ISFModVars.Shipments[modGUID] then
--         ISFModVars.Shipments[modGUID] = {}
--     end

--     VCHelpers.ModVars:Sync(ModuleUUID)
-- end

-- --- Initialize the item entries in the Shipments table for the given mod and data
-- ---@param data table The item data to submit
-- ---@param modGUID string The UUID of the mod that the item data belongs to
-- function ISUtils:InitializeItemEntries(data, modGUID)
--     local ISFModVars = Ext.Vars.GetModVariables(ModuleUUID)

--     -- For each TemplateUUID in the data, create a key in the mod table with a boolean value of false
--     for _, item in pairs(data.Items) do
--         if ISFModVars.Shipments[modGUID][item.TemplateUUID] == nil then
--             ISFModVars.Shipments[modGUID][item.TemplateUUID] = false
--         end
--     end

--     VCHelpers.ModVars:Sync(ModuleUUID)
-- end

-- --- Initialize the Mailboxes table
-- function ISUtils:InitializeMailboxesTable()
--     local ISFModVars = Ext.Vars.GetModVariables(ModuleUUID)

--     -- Each index in the Mailboxes table corresponds to a player chest
--     -- Maybe use chest template name instead? Honestly, indexing feels more elegant and less complex
--     if not ISFModVars.Mailboxes then
--         ISFModVars.Mailboxes = {
--             nil,
--             nil,
--             nil,
--             nil
--         }
--     end

--     -- Use chest template name as key for the Mailboxes table
--     --     local playerChestsTemplateNames = VCHelpers.Camp:GetAllCampChestTemplateNames()
--     --     if not ISFModVars.Mailboxes then
--     --         ISFModVars.Mailboxes = {}
--     --         for _, templateName in ipairs(playerChestsTemplateNames) do
--     --             ISFModVars.Mailboxes[templateName] = ""
--     --         end
--     --     end
--     --     VCHelpers.ModVars:Sync(ModuleUUID)
--     -- end

--     VCHelpers.ModVars:Sync(ModuleUUID)
-- end

-- --- Initialize the mod vars for the mod, if they don't already exist. Might be redundant, but it's here for now.
-- ---@param data table The item data to submit
-- ---@param modGUID string The UUID of the mod that the item data belongs to
-- function ISUtils:InitializeModVarsForMod(data, modGUID)
--     self:InitializeShipmentsTable(modGUID)
--     self:InitializeItemEntries(data, modGUID)
--     VCHelpers.ModVars:Sync(ModuleUUID)
-- end

-- --- Notify the player that they have new items in their mailbox
-- ---@param item table The item that was shipped
-- ---@param modGUID string The UUID of the mod that shipped the item
-- function ISUtils:NotifyPlayer(item, modGUID)
--     local config = Config:getCfg()
--     local isNotificationEnabled = config.FEATURES.notifications.enabled
--     local shouldNotifyPlayer = item and item.Send.NotifyPlayer

--     -- ISFDebug(2,
--     --     "NotifyPlayer: isNotificationEnabled: " ..
--     --     tostring(isNotificationEnabled) .. ", shouldNotifyPlayer: " .. tostring(shouldNotifyPlayer))

--     if not (isNotificationEnabled and shouldNotifyPlayer) then
--         return
--     end

--     if ItemShipmentInstance.hasNotifiedForThisShipment == true then
--         ISFDebug(3, "Already notified player for this shipment, skipping")
--         return
--     end

--     for index, chestUUID in pairs(VCHelpers.Camp:GetAllCampChestUUIDs()) do
--         local isItemForThisChest = item.Send.To.CampChest['Player' .. index .. 'Chest']
--         if isItemForThisChest then
--             self:HandleNotifications(chestUUID, Ext.Mod.GetMod(modGUID).Info.Name)
--         end
--     end
--     ItemShipmentInstance:SetNotifiedForThisShipment(true)
-- end

-- --- Handle the notifications to be sent to the player
-- ---@param chestUUID GUIDSTRING The UUID of the chest that the item was shipped to
-- ---@param modName string The name of the mod that shipped the item
-- ---@return nil
-- function ISUtils:HandleNotifications(chestUUID, modName)
--     local config = Config:getCfg()

--     if config.FEATURES.notifications.vfx then
--         Osi.PlayEffect(Osi.GetHostCharacter(), "09ca988d-47dd-b10f-d8e4-b4744874a942")
--     end

--     -- Notify player that they have new items in their mailbox
--     VCHelpers.Loca:UpdateLocalizedMessage(Messages.Handles.mod_shipped_item_to_mailbox, modName)
--     Osi.ShowNotification(Osi.GetHostCharacter(),
--         Ext.Loca.GetTranslatedString(Messages.Handles.mod_shipped_item_to_mailbox))
--     -- VCHelpers.Timer:OnTime(2500, function()
--     --   Osi.ShowNotification(Osi.GetHostCharacter(),
--     --     Ext.Loca.GetTranslatedString(Messages.Handles.mod_shipped_item_to_mailbox))
--     -- end)

--     if config.FEATURES.notifications.ping_chest then
--         VCHelpers.Object:PingObject(chestUUID)
--     end
-- end

-- --- Get the inventory for the given UUID and remove all items that have ISF_ in their template name
-- ---@param uuid GUIDSTRING The UUID of the inventory to remove items from
-- ---@return nil
-- function ISUtils:DeleteAllISFItemsFromInventory(uuid)
--     local inventory = VCHelpers.Inventory:GetInventory(uuid, false, false)
--     if not inventory then
--         return
--     end

--     for _, item in pairs(inventory) do
--         if string.find(item.TemplateName, "ISF_") then
--             ISFWarn(0, "Removing item %s (%s) from inventory %s (%s)", item.TemplateName, item.Name, uuid,
--                 VCHelpers.Loca:GetDisplayName(uuid))
--             Osi.RequestDelete(item.Guid)
--         end
--     end
-- end
