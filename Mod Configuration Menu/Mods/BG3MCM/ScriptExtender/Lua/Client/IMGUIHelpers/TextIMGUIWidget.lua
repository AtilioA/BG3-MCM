---@class TextIMGUIWidget: IMGUIWidget
TextIMGUIWidget = _Class:Create("TextIMGUIWidget", IMGUIWidget)

---@return any
function TextIMGUIWidget:CreateWidget(group, widgetName, setting, initialValue, modGUID)
    local text = group:AddInputText(widgetName, initialValue)
    text.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Value, modGUID)
    end
    return text
end
