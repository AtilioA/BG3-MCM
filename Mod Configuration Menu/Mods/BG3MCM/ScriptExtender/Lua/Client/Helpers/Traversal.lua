-- NodeTypeStrategy interface for constructing different IDContexts
---@class NodeTypeStrategy
NodeTypeStrategy = {}
NodeTypeStrategy.__index = NodeTypeStrategy
---@param modUUID string The UUID of the mod
---@param settingID string The ID of the setting
---@return string - The constructed ID context
function NodeTypeStrategy:ConstructIDContext(modUUID, settingID)
    error("This method should be overridden by specific strategies")
end

-- Implement specific strategies
---@class SettingWidgetStrategy : NodeTypeStrategy
SettingWidgetStrategy = setmetatable({}, NodeTypeStrategy)

---@param modUUID string The UUID of the mod
---@param settingID string The ID of the setting
---@return string - The constructed ID context
function SettingWidgetStrategy:ConstructIDContext(modUUID, settingID)
    return modUUID .. "_" .. settingID
end

---@class ResetButtonStrategy : NodeTypeStrategy
ResetButtonStrategy = setmetatable({}, { __index = NodeTypeStrategy })

---@param modUUID string The UUID of the mod
---@param settingID string The ID of the setting
---@return string - The constructed ID context
function ResetButtonStrategy:ConstructIDContext(modUUID, settingID)
    return modUUID .. "_ResetButton_" .. settingID
end

---@class DescriptionStrategy : NodeTypeStrategy
DescriptionStrategy = setmetatable({}, NodeTypeStrategy)
DescriptionStrategy.__index = DescriptionStrategy

---@param groupIDContext string The ID context of the group
---@param settingID string The ID of the setting
---@return string - The constructed ID context
function DescriptionStrategy:ConstructIDContext(groupIDContext, settingID)
    return groupIDContext .. "_Description_" .. settingID
end

---@class WidgetTooltipStrategy : NodeTypeStrategy
WidgetTooltipStrategy = setmetatable({}, NodeTypeStrategy)
WidgetTooltipStrategy.__index = WidgetTooltipStrategy

---@param modUUID string The UUID of the mod
---@param settingID string The ID of the setting
---@return string - The constructed ID context
function WidgetTooltipStrategy:ConstructIDContext(modUUID, settingID)
    return modUUID .. "WidgetTooltip_" .. settingID
end

---@class PreviousButtonStrategy : NodeTypeStrategy
PreviousButtonStrategy = setmetatable({}, NodeTypeStrategy)
PreviousButtonStrategy.__index = PreviousButtonStrategy

---@param modUUID string The UUID of the mod
---@param settingID string The ID of the setting
---@return string - The constructed ID context
function PreviousButtonStrategy:ConstructIDContext(modUUID, settingID)
    return modUUID .. "_PreviousButton_" .. settingID
end

---@class NextButtonStrategy : NodeTypeStrategy
NextButtonStrategy = setmetatable({}, NodeTypeStrategy)
NextButtonStrategy.__index = NextButtonStrategy

---@param modUUID string The UUID of the mod
---@param settingID string The ID of the setting
---@return string - The constructed ID context
function NextButtonStrategy:ConstructIDContext(modUUID, settingID)
    return modUUID .. "_NextButton_" .. settingID
end

-- NodeFinder class to find nodes using strategies
NodeFinder = {}
NodeFinder.__index = NodeFinder
---@param strategy NodeTypeStrategy The strategy used to construct the ID context
---@param modUUID string The UUID of the mod
---@param settingID string The ID of the setting
---@return any|nil The found node or nil if not found
function NodeFinder:SearchNodeByID(strategy, modUUID, settingID)
    local root = MCM_WINDOW
    if not root or not strategy or not modUUID or not settingID then return nil end

    local targetIDContext = strategy:ConstructIDContext(modUUID, settingID)

    local function traverse(node)
        local success, result = xpcall(function()
            if not targetIDContext or not node then return nil end
            if node.IDContext == targetIDContext then return node end

            for _, child in ipairs(node.Children or {}) do
                local result = traverse(child)
                if result then return result end
            end

            return nil
        end, function(err)
            MCMDebug(1, "Error in Traversal.lua: " .. err)
            return nil
        end)

        if success then
            return result
        else
            return nil
        end
    end

    return traverse(root)
end

-- Ext.Timer.WaitFor(2000, function()
--     local nodeFinder = setmetatable({}, NodeFinder)
--     local foundNode = nodeFinder:SearchNodeByID(ResetButtonStrategy, "1c132ec4-4cd2-4c40-aeb9-ff6ee0467da8",
--         "mod_enabled")
--     if foundNode then
--         _D("Node found: ")
--         _DS(foundNode)
--     else
--         _D("Node not found.")
--     end
-- end)

Ext.RegisterConsoleCommand("mcm_find_node", function(command, settingID)
    local nodeFinder = setmetatable({}, NodeFinder)
    local foundNode = nodeFinder:SearchNodeByID(ResetButtonStrategy, ModuleUUID, settingID)
    _D(foundNode)
end)

-- Function to create a flat mapping of all nodes under MCM_WINDOW
function CreateNodeMapping()
    local mapping = {}
    local root = MCM_WINDOW

    if not root then
        _D("MCM_WINDOW is not defined.")
        return mapping
    end

    -- Recursive traversal function
    local function traverse(node)
        if not node then return end

        local key = node.IDContext or node.ID or tostring(node)

        if key then
            mapping[key] = node
        else
            _D("Node without a unique identifier found.")
        end

        -- Traverse children if any
        if node.Children then
            for _, child in ipairs(node.Children) do
                xpcall(function() traverse(child) end, function(err)
                    -- _D("Error traversing child node: " .. tostring(err))
                end)
            end
        end
    end

    -- Start traversal from the root
    traverse(root)

    return mapping
end

-- Register the console command to create and display the node mapping
Ext.RegisterConsoleCommand("mcm_create_mapping", function(command, elementKey)
    _D("Attempting to create node mapping...")
    local mapping = CreateNodeMapping()

    if not next(mapping) then
        _D("No nodes found in MCM_WINDOW.")
        return
    end

    -- Function to pretty-print the mapping table
    local function PrintMapping(map)
        for key, node in pairs(map) do
            _D(string.format("Key: %s, Node: %s", key, tostring(node)))
        end
    end
    if elementKey then
        local idc = ResetButtonStrategy:ConstructIDContext(ModuleUUID, elementKey)
        _D(idc)
        local specificNode = mapping[idc]
        if specificNode then
            _DS(specificNode)
        else
            _D(string.format("No node found for Key '%s'.", elementKey))
        end
    else
        _D("Node Mapping:")
        PrintMapping(mapping)
    end
end)
