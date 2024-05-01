---@class TextIMGUIWidget: IMGUIWidget
TextIMGUIWidget = _Class:Create("TextIMGUIWidget", IMGUIWidget)

function TextIMGUIWidget:new(group, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = TextIMGUIWidget })
    instance.Widget = group:AddInputText("", initialValue)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Text, modGUID)
    end
    instance.Widget.AutoSelectAll = true
    return instance
end

function TextIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Text = value
end
