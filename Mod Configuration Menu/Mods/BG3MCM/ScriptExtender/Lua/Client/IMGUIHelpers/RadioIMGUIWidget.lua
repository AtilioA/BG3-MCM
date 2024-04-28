---@class RadioIMGUIWidget: IMGUIWidget
RadioIMGUIWidget = _Class:Create("RadioIMGUIWidget", IMGUIWidget)

---@param value number
---@return table buttons The buttons created
function RadioIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    if not group or not setting or not modGUID then
        return {}
    end

    group:AddText(setting.Name)
    local buttons = self:CreateRadioButtons(group, setting, settingValue)
    self:SetRadioButtonCallbacks(buttons, setting, modGUID)
    return buttons
end

---@param group any The IMGUI group to add the radio buttons to
---@param setting SchemaSetting The setting containing the radio button options
---@param settingValue any The current value of the setting
---@return table buttons The created radio buttons
function RadioIMGUIWidget:CreateRadioButtons(group, setting, settingValue)
    local buttons = {}
    local options = { table.unpack(setting.Options.Choices) }
    for i, option in ipairs(options) do
        local isActive = option == settingValue
        local radioButton = group:AddRadioButton(option, isActive)
        if i > 1 then
            radioButton.SameLine = true
        end
        table.insert(buttons, radioButton)
    end
    return buttons
end

---@param buttons table The radio buttons to set callbacks for
---@param setting SchemaSetting The setting containing the radio button options
---@param modGUID string The UUID of the mod
function RadioIMGUIWidget:SetRadioButtonCallbacks(buttons, setting, modGUID)
    for _, button in ipairs(buttons) do
        button.OnChange = function(value)
            if value and value.Label then
                IMGUILayer:SetConfigValue(setting.Id, value.Label, modGUID)
                self:UncheckOtherRadioButtons(buttons, button)
            end
        end
    end
end

---@param buttons table The radio buttons to uncheck
---@param activeButton any The currently active radio button
function RadioIMGUIWidget:UncheckOtherRadioButtons(buttons, activeButton)
    activeButton.Active = true
    for _, button in ipairs(buttons) do
        if button ~= activeButton then
            button.Active = false
        end
    end
end
