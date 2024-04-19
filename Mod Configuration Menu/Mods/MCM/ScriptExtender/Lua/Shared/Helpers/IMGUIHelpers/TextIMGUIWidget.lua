---@class TextIMGUIWidget: IMGUIWidget
TextIMGUIWidget = _Class:Create("TextIMGUIWidget", IMGUIWidget)

---@param value string
---@return any
function TextIMGUIWidget.Create(group, setting, settingValue, modGUID)
    local text = group:AddText(setting.Name, settingValue)
    local tooltip = text:Tooltip()
    tooltip:AddText(setting.Description)
    text.OnChange = function(value)
        BG3MCM:SetConfigValue(setting.Id, value.Value, modGUID)
    end
    return text
end
