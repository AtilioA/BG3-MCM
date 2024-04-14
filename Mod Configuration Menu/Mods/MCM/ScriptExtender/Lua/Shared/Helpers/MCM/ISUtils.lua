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
