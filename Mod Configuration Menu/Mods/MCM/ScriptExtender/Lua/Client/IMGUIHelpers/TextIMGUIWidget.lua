---@class TextIMGUIWidget: IMGUIWidget
TextIMGUIWidget = _Class:Create("TextIMGUIWidget", IMGUIWidget)

---@param value string
---@return any
function TextIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    local text = group:AddInputText(setting.Name, settingValue)
    text.OnChange = function(value)
        IMGUILayer:SetConfigValue(setting.Id, value.Value, modGUID)
    end
    return text
end
