---@class RadioIMGUIWidget: IMGUIWidget
RadioIMGUIWidget = _Class:Create("RadioIMGUIWidget", IMGUIWidget)

---@param value number
---@return table buttons The buttons created
function RadioIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    local buttons = {}
    local options = { table.unpack(setting.Options.Choices) }
    for i, option in ipairs(options) do
        local radioButton = group:AddRadioButton(setting.Name, setting.Name == settingValue)
        radioButton.OnChange = function(value)
            BG3MCM:SetConfigValue(setting.Id, value.Value[1], modGUID)
        end
        table.insert(buttons, radioButton)
    end
    return buttons
end
