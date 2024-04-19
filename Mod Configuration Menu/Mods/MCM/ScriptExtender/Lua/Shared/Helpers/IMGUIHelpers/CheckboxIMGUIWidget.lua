---@class CheckboxIMGUIWidget: IMGUIWidget
CheckboxIMGUIWidget = _Class:Create("CheckboxIMGUIWidget", IMGUIWidget)

---@param value number
---@return any widget
function CheckboxIMGUIWidget.Create(group, setting, settingValue, modGUID)
    local checkbox = group:AddCheckbox(setting.Name, settingValue)
    local tooltip = checkbox:Tooltip()
    tooltip:AddText(setting.Description)
    checkbox.OnChange = function(value)
        BG3MCM:SetConfigValue(setting.Id, value.Checked, modGUID)
    end
    return checkbox
end
