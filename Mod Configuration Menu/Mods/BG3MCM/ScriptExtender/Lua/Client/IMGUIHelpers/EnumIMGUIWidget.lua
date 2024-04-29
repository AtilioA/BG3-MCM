---@class EnumIMGUIWidget
EnumIMGUIWidget = _Class:Create("EnumIMGUIWidget", IMGUIWidget)

function EnumIMGUIWidget:CreateWidget(group, widgetName, setting, initialValue, modGUID)
    local options = setting.Options.Choices
    local comboInput = group:AddCombo(widgetName, initialValue)
    comboInput.Options = options

    -- Set initial selection
    for i, value in ipairs(options) do
        if value == initialValue then
            comboInput.SelectedIndex = i - 1
            break
        end
    end

    comboInput.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, options[value.SelectedIndex + 1], modGUID)
    end

    return comboInput
end
