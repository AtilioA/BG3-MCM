---@class CheckboxIMGUIWidget: IMGUIWidget
CheckboxIMGUIWidget = _Class:Create("CheckboxIMGUIWidget", IMGUIWidget)

---@return any widget
function CheckboxIMGUIWidget:CreateWidget(group, widgetName, setting, initialValue, modGUID)
    local checkbox = group:AddCheckbox(widgetName, initialValue)
    checkbox.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Checked, modGUID)
    end
    return checkbox
end
