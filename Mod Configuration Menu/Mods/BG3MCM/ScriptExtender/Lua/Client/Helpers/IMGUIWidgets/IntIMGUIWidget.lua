---@class IntIMGUIWidget: IMGUIWidget
IntIMGUIWidget = _Class:Create("IntIMGUIWidget", IMGUIWidget)

function IntIMGUIWidget:new(group, widgetName, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = IntIMGUIWidget })
    instance.Widget = group:AddInputInt(widgetName, initialValue)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return instance
end

function IntIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end
