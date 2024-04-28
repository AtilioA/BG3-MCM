---@class DragIntIMGUIWidget: IMGUIWidget
DragIntIMGUIWidget = _Class:Create("DragIntIMGUIWidget", IMGUIWidget)

---@return any
function DragIntIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    local slider = group:AddDragInt(setting.Name, settingValue, setting.Options.Min, setting.Options.Max)
    slider.OnChange = function(value)
        IMGUILayer:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return slider
end
