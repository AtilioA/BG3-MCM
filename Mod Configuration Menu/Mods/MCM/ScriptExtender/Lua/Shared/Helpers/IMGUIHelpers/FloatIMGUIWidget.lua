---@class FloatIMGUIWidget: IMGUIWidget
FloatIMGUIWidget = _Class:Create("FloatIMGUIWidget", IMGUIWidget)

---@param value number
---@return boolean
function FloatIMGUIWidget.Create(group, setting, settingValue, modGUID)
    local inputScalar = group:AddInputScalar(setting.Name, settingValue)
    local tooltip = inputScalar:Tooltip()
    tooltip:AddText(setting.Description)
    inputScalar.OnChange = function(value)
        BG3MCM:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return inputScalar
end
