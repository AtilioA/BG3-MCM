---@class EnumIMGUIWidget
EnumIMGUIWidget = _Class:Create("EnumIMGUIWidget", IMGUIWidget)

function EnumIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    local options = setting.Options.Choices
    local comboInput = group:AddCombo(setting.Name, settingValue)
    comboInput.Options = options

    -- Set initial selection
    for i, value in ipairs(options) do
        if value == settingValue then
            comboInput.SelectedIndex = i - 1
            break
        end
    end

    comboInput.OnChange = function(value)
        IMGUILayer:SetConfigValue(setting.Id, options[value.SelectedIndex + 1], modGUID)
    end

    return comboInput
end
