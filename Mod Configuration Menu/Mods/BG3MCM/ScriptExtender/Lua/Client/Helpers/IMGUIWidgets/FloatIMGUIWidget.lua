---@class FloatIMGUIWidget: IMGUIWidget
FloatIMGUIWidget = _Class:Create("FloatIMGUIWidget", IMGUIWidget)

function FloatIMGUIWidget:new(group, widgetName, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = FloatIMGUIWidget })
    instance.Widget = group:AddInputScalar(widgetName, initialValue)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return instance
end

function FloatIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end
