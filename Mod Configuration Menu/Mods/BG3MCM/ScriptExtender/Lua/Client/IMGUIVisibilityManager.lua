---@class IMGUIVisibilityManager: MetaClass
IMGUIVisibilityManager = _Class:Create("IMGUIVisibilityManager", nil, {
    visibilityTriggers = {},
    uiElementByName = {},
    operators = {
        ["=="] = function(a, b) return a == b end,
        ["!="] = function(a, b) return a ~= b end,
        ["<="] = function(a, b) return a <= b end,
        [">="] = function(a, b) return a >= b end,
        ["<"] = function(a, b) return a < b end,
        [">"] = function(a, b) return a > b end,
        ["isVisible"] = function(a, b) return a == b end
    }
})


---
function IMGUIVisibilityManager:manageVisibleIf(modGUID, elementInfo, uiElement)
    if elementInfo.VisibleIf and elementInfo.VisibleIf.Conditions then
        if self:EvaluateVisibleIf(modGUID, elementInfo.VisibleIf, elementInfo.Name or elementInfo.SectionName or elementInfo.TabName ) then -- change for generic Name ...
            self.visibilityTriggers[modGUID] = self.visibilityTriggers[modGUID] or {}
            self.visibilityTriggers[modGUID][uiElement] = elementInfo.VisibleIf
        end
    end

    self.uiElementByName[modGUID] = self.uiElementByName[modGUID] or {}
    self.uiElementByName[modGUID][elementInfo.TabId or elementInfo.SectionId or elementInfo.Id] = uiElement  -- change for generic Id ...
end


function IMGUIVisibilityManager:EvaluateVisibleIf(modGUID, visibleIf, elementName)
    local valid = true
    -- control LogicalOperator is valid if present
    if visibleIf.LogicalOperator ~= nil and visibleIf.LogicalOperator ~= "or" and  visibleIf.LogicalOperator ~= "and" then
        MCMWarn(0,
                "Invalid LogicalOperator passed by mod '" ..
                        Ext.Mod.GetMod(modGUID).Info.Name ..
                        "' for visibility condition of '"..elementName.."'. Please contact " ..
                        Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
        valid = false
    end

    -- Control Conditions
    for _, condition in ipairs(visibleIf.Conditions) do
        if condition.SettingId == nil then
            MCMWarn(0,
                    "Invalid condition (no settingId) passed by mod '" ..
                            Ext.Mod.GetMod(modGUID).Info.Name ..
                            "' for visibility condition of '"..elementName.."'. Please contact " ..
                            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
            valid = false
        end
        if condition.Operator == nil then
            MCMWarn(0,
                    "Invalid condition (no operator) passed by mod '" ..
                            Ext.Mod.GetMod(modGUID).Info.Name ..
                            "' for visibility condition of '"..elementName.."'. Please contact " ..
                            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
            valid = false
        else
            if self.operators[condition.Operator] == nil then
                MCMWarn(0,
                        "Invalid condition (invalid operator: "..condition.Operator..") passed by mod '" ..
                                Ext.Mod.GetMod(modGUID).Info.Name ..
                                "' for visibility condition of '"..elementName.."'. Please contact " ..
                                Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
                valid = false
            end
        end
        if condition.ExpectedValue == nil then
            MCMWarn(0,
                    "Invalid condition (no triggerValue) passed by mod '" ..
                            Ext.Mod.GetMod(modGUID).Info.Name ..
                            "' for visibility condition of '"..elementName.."'. Please contact " ..
                            Ext.Mod.GetMod(modGUID).Info.Author .. " about this issue.")
            valid = false
        end
    end

    return valid
end

function IMGUIVisibilityManager:UpdateAllVisibility()
    for _, modGUID in ipairs(self.visibilityTriggers) do
        for _, uiElement in pairs(self.visibilityTriggers[modGUID]) do
            IMGUIVisibilityManager:UpdateVisibilityOfUiElement(modGUID, uiElement, false)
        end
    end
end


-- TODO: this should be refactored to use OOP or at least be more modular, however I've wasted too much time on this already with Lua's nonsense, so I'm stashing and leaving it as is
function IMGUIVisibilityManager:UpdateVisibility_SettingChanged(modGUID, settingId)
    if not modGUID or not settingId then
        return
    end

    local visibilityTriggers = self.visibilityTriggers[modGUID] or {}
    for uiElement, visibleIf in pairs(visibilityTriggers) do
        for _, condition in ipairs(visibleIf.Conditions) do
            if condition.SettingId == settingId then
                self:UpdateVisibilityOfUiElement(modGUID, uiElement, true)
                break
            end
        end
    end
end

function IMGUIVisibilityManager:UpdateVisibility_GroupVisibilityChanged(modGUID, uiElementChanged)
    local visibilityTriggers = self.visibilityTriggers[modGUID] or {}
    for uiElement, visibleIf in pairs(visibilityTriggers) do
        for _, condition in ipairs(visibleIf.Conditions) do
            if condition.Operator == "isVisible" and self.uiElementByName[modGUID][condition.SettingId] == uiElementChanged then
                self:UpdateVisibilityOfUiElement(modGUID, uiElement, true)
                break
            end
        end
    end
end


function IMGUIVisibilityManager:UpdateVisibilityOfUiElement(modGUID, uiElement, transmitVisibilityChanged)
    local visibilityTriggers = self.visibilityTriggers[modGUID] or {}
    local visibleIf = visibilityTriggers[uiElement]
    local logicalOperator = visibleIf.LogicalOperator or "and"
    local visible = true
    if logicalOperator == "or" then
        visible = false
    end

    for _, condition in ipairs(visibleIf.Conditions) do
        local settingIdTriggering = condition.SettingId
        local operator = condition.Operator
        local triggerValue = condition.ExpectedValue

        local value = nil
        if operator == "isVisible" then
            value = self.uiElementByName[modGUID][settingIdTriggering].Visible
        else
            value = MCMClientState:GetClientStateValue(settingIdTriggering, modGUID)
        end

        local strValue, strTrigger = tostring(value), tostring(triggerValue)
        local numValue, numTrigger = tonumber(value), tonumber(triggerValue)

        local v = nil
        if operator == "==" or operator == "!="  or operator == "isVisible" then
            v = self.operators[operator](strValue, strTrigger)
        elseif numValue ~= nil and numTrigger ~= nil then
            v = self.operators[operator](numValue, numTrigger)
        else
            MCMWarn(0,
                    "Something go wrong, contact MCM support.") -- should never happen (trigegr is not empty at that point, value from widget too)
            v = false
        end

        if v and (logicalOperator == "or") then
            visible = true
            break
        elseif (not v) and (logicalOperator == "and") then
            visible = false
            break
        end
    end
    local visibilityChanged = (uiElement.Visible ~= visible)
    if transmitVisibilityChanged and visibilityChanged then
        uiElement.Visible = visible
        self:UpdateVisibility_GroupVisibilityChanged(modGUID, uiElement)
    end
end