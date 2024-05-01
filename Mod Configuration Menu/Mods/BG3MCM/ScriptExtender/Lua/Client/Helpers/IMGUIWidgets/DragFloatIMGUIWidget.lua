---@class DragFloatIMGUIWidget: IMGUIWidget
DragFloatIMGUIWidget = _Class:Create("DragFloatIMGUIWidget", IMGUIWidget)

function DragFloatIMGUIWidget:new(group, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = DragFloatIMGUIWidget })
    instance.Widget = group:AddDrag("", initialValue, setting.Options.Min, setting.Options.Max)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return instance
end

function DragFloatIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end
