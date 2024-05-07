---@class RadioIMGUIWidget: IMGUIWidget
RadioIMGUIWidget = _Class:Create("RadioIMGUIWidget", IMGUIWidget)

---@param value number
---@return table buttons The buttons created
function RadioIMGUIWidget:new(group, setting, initialValue, modGUID)
    if not group or not setting or not modGUID then
        return {}
    end

    local instance = setmetatable({}, { __index = RadioIMGUIWidget })
    instance.Widget = self:CreateRadioButtons(group, setting, initialValue)
    self:SetRadioButtonCallbacks(instance.Widget, setting, modGUID)
    return instance
end

---@param group any The IMGUI group to add the radio buttons to
---@param setting BlueprintSetting The setting containing the radio button options
---@param initialValue any The current value of the setting
function RadioIMGUIWidget:CreateRadioButtons(group, setting, initialValue)
    local buttons = {}
    local options = { table.unpack(setting:GetOptions().Choices) }
    for i, option in ipairs(options) do
        local isActive = option == initialValue
        local radioButton = group:AddRadioButton(option, isActive)
        radioButton.IDContext = string.format("radioButton_%s_%s", setting:GetId(), i)
        if i > 1 then
            radioButton.SameLine = true
        end
        table.insert(buttons, radioButton)
    end
    return buttons
end

---@param buttons table The radio buttons to set callbacks for
---@param setting BlueprintSetting The setting containing the radio button options
---@param modGUID string The UUID of the mod
function RadioIMGUIWidget:SetRadioButtonCallbacks(buttons, setting, modGUID)
    for _, button in ipairs(buttons) do
        button.OnChange = function(value)
            if value and value.Label then
                IMGUIAPI:SetSettingValue(setting:GetId(), value.Label, modGUID)
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

function RadioIMGUIWidget:UpdateCurrentValue(value)
    for _, button in ipairs(self.Widget) do
        button.Active = button.Label == value
    end
end
