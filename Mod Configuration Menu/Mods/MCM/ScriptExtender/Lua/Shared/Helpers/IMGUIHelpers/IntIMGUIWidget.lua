---@class IntIMGUIWidget: IMGUIWidget
IntIMGUIWidget = _Class:Create("IntIMGUIWidget", IMGUIWidget)

---@param value number
---@return any
function IntIMGUIWidget.Create(group, setting, settingValue, modGUID)
    local inputInt = group:AddInputInt(setting.Name, settingValue)
    inputInt.OnChange = function(value)
        BG3MCM:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return inputInt
end
