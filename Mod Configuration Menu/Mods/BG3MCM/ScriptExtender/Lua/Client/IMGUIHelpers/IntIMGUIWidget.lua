---@class IntIMGUIWidget: IMGUIWidget
IntIMGUIWidget = _Class:Create("IntIMGUIWidget", IMGUIWidget)

---@return any
function IntIMGUIWidget:CreateWidget(group, widgetName, setting, initialValue, modGUID)
    local inputInt = group:AddInputInt(widgetName, initialValue)
    inputInt.OnChange = function(value)
        IMGUILayer:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return inputInt
end
