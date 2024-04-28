---@class DragFloatIMGUIWidget: IMGUIWidget
DragFloatIMGUIWidget = _Class:Create("DragFloatIMGUIWidget", IMGUIWidget)

---@return any
function DragFloatIMGUIWidget:CreateWidget(group, widgetName, setting, initialValue, modGUID)
    local drag = group:AddDrag(widgetName, initialValue, setting.Options.Min, setting.Options.Max)
    drag.OnChange = function(value)
        IMGUILayer:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return drag
end
