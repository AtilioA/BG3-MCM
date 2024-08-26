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
        if not targetIDContext or not node then return nil end
        if node.IDContext == targetIDContext then return node end

        for _, child in ipairs(node.Children or {}) do
            local result = traverse(child)
            if result then return result end
        end

        return nil
    end

    return traverse(root)
end

local nodeFinder = setmetatable({}, NodeFinder)
local foundNode = nodeFinder:SearchNodeByID(ResetButtonStrategy, "1c132ec4-4cd2-4c40-aeb9-ff6ee0467da8", "mod_enabled")
if foundNode then
    _D("Node found: ")
    _DS(foundNode)
else
    _D("Node not found.")
end
