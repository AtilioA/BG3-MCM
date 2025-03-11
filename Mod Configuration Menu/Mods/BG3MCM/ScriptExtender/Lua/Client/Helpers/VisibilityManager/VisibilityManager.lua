------------------------------------------------------------
-- VisibilityManager module
-- Handles UI element visibility using VisibleIf definitions from blueprints.
------------------------------------------------------------

VisibilityManager = {}
VisibilityManager.__index = VisibilityManager

-- Internal table mapping modUUID to a table of UI elements and their condition groups.
VisibilityManager.registered = {}

--- Registers a UI element with its associated visibility condition group.
--- Immediately evaluates and sets the initial visibility.
--- @param modUUID string - The mod's unique identifier.
--- @param uiElement table - The UI element to control visibility.
--- @param conditionGroup table - The visibility condition group following the VisibleIf JSON schema.
function VisibilityManager.registerCondition(modUUID, uiElement, conditionGroup)
    if not modUUID or not uiElement or not conditionGroup then
        MCMWarn(0, "Failed to register visibility condition: missing modUUID, UI element, or condition group.")
        return
    end

    VisibilityManager.registered[modUUID] = VisibilityManager.registered[modUUID] or {}
    VisibilityManager.registered[modUUID][uiElement] = conditionGroup

    -- Evaluate and apply the initial visibility.
    uiElement.Visible = VisibilityManager.evaluateGroup(modUUID, conditionGroup)
end

--- Evaluates an entire group of conditions for a mod.
--- Caches mod info for all conditions in the group.
--- @param modUUID string - The mod's unique identifier.
--- @param conditionGroup table - A table containing "LogicalOperator" and "Conditions" keys.
--- @return boolean True if the conditions pass (combined per LogicalOperator), false otherwise.
function VisibilityManager.evaluateGroup(modUUID, conditionGroup)
    local modInfo = Ext.Mod.GetMod(modUUID).Info
    local modName = modInfo.Name
    local modAuthor = modInfo.Author

    local logicalOp = conditionGroup.LogicalOperator or "and"
    local conditions = conditionGroup.Conditions
    if not conditions or type(conditions) ~= "table" or #conditions == 0 then
        -- No conditions provided means no restrictions; default to visible.
        return true
    end

    if logicalOp == "and" then
        for _, cond in ipairs(conditions) do
            if not VisibilityManager.evaluateConditionWithInfo(modName, modAuthor, modUUID, cond) then
                return false
            end
        end
        return true
    elseif logicalOp == "or" then
        for _, cond in ipairs(conditions) do
            if VisibilityManager.evaluateConditionWithInfo(modName, modAuthor, modUUID, cond) then
                return true
            end
        end
        return false
    else
        MCMWarn(0, "Unknown logical operator '" .. tostring(logicalOp) .. "' for mod '" ..
            modName .. "'. Please contact " .. modAuthor .. ".")
        return false
    end
end

--- Evaluates a single condition for a mod using cached mod info.
--- @param modName string - The mod's name.
--- @param modAuthor string - The mod author's name.
--- @param modUUID string - The mod's unique identifier.
--- @param cond table - A condition object with 'SettingId', 'Operator', and 'ExpectedValue'.
--- @return boolean True if the condition passes, false otherwise.
function VisibilityManager.evaluateConditionWithInfo(modName, modAuthor, modUUID, cond)
    local currentValue = MCMRendering:GetClientStateValue(cond.SettingId, modUUID)
    if currentValue == nil then
        MCMWarn(0, "Missing value for setting '" .. cond.SettingId ..
            "' required for visibility condition in mod '" .. modName ..
            "'. Please contact " .. modAuthor .. ".")
        return false
    end

    local op = cond.Operator
    if op == "==" then
        return tostring(currentValue) == tostring(cond.ExpectedValue)
    elseif op == "!=" then
        return tostring(currentValue) ~= tostring(cond.ExpectedValue)
    elseif op == ">" or op == "<" or op == ">=" or op == "<=" then
        local numCurrent = tonumber(currentValue)
        local numExpected = tonumber(cond.ExpectedValue)
        if numCurrent == nil or numExpected == nil then
            MCMWarn(0, "Non-numeric value encountered for numeric comparison in setting '" ..
                cond.SettingId .. "' in mod '" .. modName ..
                "'. Please contact " .. modAuthor .. ".")
            return false
        end
        if op == ">" then
            return numCurrent > numExpected
        elseif op == "<" then
            return numCurrent < numExpected
        elseif op == ">=" then
            return numCurrent >= numExpected
        elseif op == "<=" then
            return numCurrent <= numExpected
        end
    else
        MCMWarn(0, "Invalid comparison operator: '" .. op ..
            "' for mod '" .. modName .. "' in setting '" .. cond.SettingId ..
            "'. Please contact " .. modAuthor .. ".")
        return false
    end
end

--- Handles a setting update event by re-evaluating all registered UI elements
--- that depend on the updated setting.
--- @param modUUID string - The mod's unique identifier.
--- @param settingId string - The ID of the setting that was updated.
--- @param value any - The new value (evaluation still uses MCMRendering to fetch the current value).
function VisibilityManager.handleSettingUpdate(modUUID, settingId, value)
    --- Defer evaluation by one tick to ensure MCMRendering is up-to-date.
    VCTimer:OnTicks(1, function()
        local modElements = VisibilityManager.registered[modUUID]
        if not modElements then return end

        for uiElement, conditionGroup in pairs(modElements) do
            local shouldReevaluate = false
            for _, cond in ipairs(conditionGroup.Conditions or {}) do
                if cond.SettingId == settingId then
                    shouldReevaluate = true
                    break
                end
            end

            if shouldReevaluate then
                local newVisibility = VisibilityManager.evaluateGroup(modUUID, conditionGroup)
                if uiElement.Visible ~= newVisibility then
                    uiElement.Visible = newVisibility
                end
            end
        end
    end)
end

-- Subscribe to setting update events.
ModEventManager:Subscribe(EventChannels.MCM_INTERNAL_SETTING_SAVED, function(payload)
    local modUUID = payload.modUUID
    local settingId = payload.settingId
    local newValue = payload.value
    VisibilityManager.handleSettingUpdate(modUUID, settingId, newValue)
end)

return VisibilityManager
