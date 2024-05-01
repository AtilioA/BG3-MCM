---@class DragIntIMGUIWidget: IMGUIWidget
DragIntIMGUIWidget = _Class:Create("DragIntIMGUIWidget", IMGUIWidget)

function DragIntIMGUIWidget:new(group, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = DragIntIMGUIWidget })
    instance.Widget = group:AddDragInt("", initialValue, setting.Options.Min, setting.Options.Max)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modGUID)
    end
    return instance
end

function DragIntIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end
