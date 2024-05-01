---@class TextIMGUIWidget: IMGUIWidget
TextIMGUIWidget = _Class:Create("TextIMGUIWidget", IMGUIWidget)

function TextIMGUIWidget:new(group, widgetName, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = TextIMGUIWidget })
    instance.Widget = group:AddInputText(widgetName, initialValue)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Text, modGUID)
    end
    return instance
end

function TextIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Text = value
end
