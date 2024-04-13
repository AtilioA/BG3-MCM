-- ---@class HelperISCommands: Helper
-- ISCommands = _Class:Create("HelperISCommands", Helper)

-- --- SE console command for shipping items from all mods.
-- ---@param modUUID string The UUID of the mod being processed
-- ---@param skipChecks string Whether to skip checking if the item already exists
-- ---@return nil
-- Ext.RegisterConsoleCommand('isf_ship_all', function(cmd, skipChecks)
--     local boolSkipChecks = skipChecks == 'true'
--     local trigger = "ConsoleCommand"
--     ItemShipmentInstance:SetShipmentTrigger(trigger)

--     ItemShipmentInstance:LoadShipments()
--     ItemShipmentInstance:ProcessShipments(boolSkipChecks)
-- end)

-- --- SE console command for shipping items for a specific mod passed as argument.
-- ---@example isf_ship_mod 12345678-1234-1234-1234-123456789012 true
-- ---@param modUUID string The UUID of the mod being processed
-- ---@param skipChecks string Whether to skip checking if the item already exists
-- ---@return nil
-- Ext.RegisterConsoleCommand('isf_ship_mod', function(cmd, modUUID, skipChecks)
--     local boolSkipChecks = skipChecks == 'true'
--     local trigger = "ConsoleCommand"
--     ItemShipmentInstance:SetShipmentTrigger(trigger)

--     ItemShipmentInstance:LoadShipments()
--     ItemShipmentInstance:ProcessModShipments(modUUID, boolSkipChecks)
-- end)

-- --- SE console command for uninstalling Item Shipment Framework.
-- -- NOTE: ModVars are wiped after saving without the mod loaded
-- ---@return nil
-- Ext.RegisterConsoleCommand('isf_uninstall', function(cmd)
--     ISFWarn(0,
--         "Uninstalling A&V Item Shipment Framework. All non-ISF items from the mailboxes may be moved to the camp chests. Mailboxes will be deleted.")

--     VCHelpers.MessageBox:DustyMessageBox('isf_uninstall_move_items',
--         Messages.ResolvedMessages.uninstall_should_move_out_of_mailboxes)
-- end)

-- --- SE console command for refilling all mailboxes with items.
-- --- The refill will add the difference between the mailbox and the camp chest. Any missing items from the mailbox will be added, regardless of existence checks. However, only the difference will be added. If the item configuration declares that 2 copies of an item should be in the mailbox, but there is already 1, only 1 will be added.
-- --- This also updates the tutorial chests in the mailboxes.
-- Ext.RegisterConsoleCommand('isf_refill', function(cmd)
--     ISFPrint(0, "Refilling all mailboxes with items.")

--     ItemShipmentInstance:LoadShipments()

--     ISMailboxes:RefillMailboxes()
-- end)

-- --- SE console command for updating tutorial chests in mailboxes.
-- Ext.RegisterConsoleCommand('isf_tut_update', function(cmd)
--     ISFPrint(0, "Updating tutorial chests in mailboxes.")
--     ISMailboxes:UpdateTutorialChests()
-- end)

-- -- Ext.RegisterConsoleCommand('isf_tt', function(cmd)
-- --     ISFWarn(0, "Testing treasure table retrieval.")
-- --     -- I don't know what I'm doing B-)
-- --     -- local template = "TUT_Chest_Potions"
-- --     -- local template = Ext.Template.GetLocalTemplate("3761acb2-5274-e2aa-bcd3-49b5d785f70b")
-- --     -- _D(Ext.Template.GetCacheTemplate("4708b966-e0a5-4551-9871-43cf42302419"))
-- --     -- _D(Ext.Template.GetLocalCacheTemplate("4708b966-e0a5-4551-9871-43cf42302419"))
-- --     -- _D(Ext.Template.GetLocalTemplate("4708b966-e0a5-4551-9871-43cf42302419"))

-- --     -- _D(Ext.Template.GetTemplate("4708b966-e0a5-4551-9871-43cf42302419"))
-- --     -- _D("== ROOT ==")
-- --     -- _D(Ext.Template.GetRootTemplate("4708b966-e0a5-4551-9871-43cf42302419"))

-- --     _D("TT")
-- --     local treasureTableName = "MEQ_Item_Container_Cloaks_TT"
-- --     local treasureTable = VCHelpers.TreasureTable:ProcessSingleTreasureTable(treasureTableName)
-- --     if treasureTable then
-- --         _D(VCHelpers.TreasureTable:ExtractTreasureCategories(treasureTable))
-- --     end
-- -- end)
