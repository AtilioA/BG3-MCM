------------------------------------------------------------
-- VisibilityManager Module
-- Responsible for registering and updating UI element visibility
-- based on conditions. Uses ReactiveX (if desired) to propagate
-- changes.
------------------------------------------------------------
VisibilityManager = {}
VisibilityManager.__index = VisibilityManager

-- Store conditions by modUUID.
VisibilityManager.conditions = {}

-- Register a set of conditions for a given UI element.
-- conditions is expected to be an array of condition objects:
-- { SettingId = <id>, Operator = "<operator>", ExpectedValue = <value> }
function VisibilityManager:registerCondition(modUUID, uiElement, conditions)
    self.conditions[modUUID] = self.conditions[modUUID] or {}
    self.conditions[modUUID][uiElement] = conditions
end

-- Update the visibility of all UI elements registered for a given mod
-- when a setting (identified by settingId) changes to the provided value.
function VisibilityManager:update(modUUID, settingId, value)
    local modConditions = self.conditions[modUUID]
    if not modConditions then return end

    for uiElement, condList in pairs(modConditions) do
        for _, cond in ipairs(condList) do
            if cond.SettingId == settingId then
                local visible = self:evaluateCondition(cond.Operator, value, cond.ExpectedValue)
                uiElement.Visible = visible
            end
        end
    end
end

-- Evaluate a simple condition.
function VisibilityManager:evaluateCondition(operator, value, expected)
    if operator == "==" then
        return value == expected
    elseif operator == "!=" then
        return value ~= expected
    elseif operator == "<" then
        return value < expected
    elseif operator == ">" then
        return value > expected
    elseif operator == "<=" then
        return value <= expected
    elseif operator == ">=" then
        return value >= expected
    end
    return false
end
