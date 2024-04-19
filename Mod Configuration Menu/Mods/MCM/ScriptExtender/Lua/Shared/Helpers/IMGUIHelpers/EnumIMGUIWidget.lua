---@class EnumIMGUIWidget: IMGUIWidget
EnumIMGUIWidget = _Class:Create("EnumIMGUIWidget", IMGUIWidget)

---@param value any
---@return any
function EnumIMGUIWidget.Create(group, setting, settingValue, modGUID)
    -- REVIEW: is this unpacking necessary?
    local options = { table.unpack(setting.Options.Choices) }
    local comboInput = group:AddCombo(setting.Name, settingValue, options)
    local tooltip = comboInput:Tooltip()
    tooltip:AddText(setting.Description)
    comboInput.OnChange = function(value)
        BG3MCM:SetConfigValue(setting.Id, options[value], modGUID)
    end
    return comboInput
end
