---@class DragIntIMGUIWidget: IMGUIWidget
DragIntIMGUIWidget = _Class:Create("DragIntIMGUIWidget", IMGUIWidget)

---@return any
function DragIntIMGUIWidget:CreateWidget(group, widgetName, setting, initialValue, modGUID)
    local slider = group:AddDragInt(widgetName, initialValue, setting.Options.Min, setting.Options.Max)
    slider.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return slider
end
