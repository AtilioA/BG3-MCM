---@class DragFloatIMGUIWidget: IMGUIWidget
DragFloatIMGUIWidget = _Class:Create("DragFloatIMGUIWidget", IMGUIWidget)

---@return any
function DragFloatIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    local drag = group:AddDrag(setting.Name, settingValue, setting.Options.Min, setting.Options.Max)
    drag.OnChange = function(value)
        IMGUILayer:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return drag
end
