---@class RadioIMGUIWidget: IMGUIWidget
RadioIMGUIWidget = _Class:Create("RadioIMGUIWidget", IMGUIWidget)

function RadioIMGUIWidget:new(group, setting, initialValue, modUUID)
    if not group or not setting or not modUUID then
        return {}
    end

    local instance = setmetatable({}, { __index = RadioIMGUIWidget })
    instance.Widget = self:CreateRadioButtons(group, setting, initialValue)
    self:SetRadioButtonCallbacks(instance.Widget, setting, modUUID)
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
        local localizedValue = self:getLocalizedValue(setting, i)
        local radioButton = group:AddRadioButton(localizedValue, isActive)
        radioButton.UserData = { OriginalValue = option }
        radioButton.IDContext = string.format("radioButton_%s_%s", setting:GetId(), i)
        if i > 1 then
            radioButton.SameLine = true
        end
        table.insert(buttons, radioButton)
    end
    return buttons
end

function RadioIMGUIWidget:getLocalizedValue(setting, index)
    local settingHandles = setting:GetHandles()
    if settingHandles and settingHandles.ChoicesHandles then
        local localizedValue = Ext.Loca.GetTranslatedString(settingHandles.ChoicesHandles[index])
        if localizedValue and localizedValue ~= "" then
            return localizedValue
        end
    end
    return setting:GetOptions().Choices[index]
end

---@param buttons table The radio buttons to set callbacks for
---@param setting BlueprintSetting The setting containing the radio button options
---@param modUUID string The UUID of the mod
function RadioIMGUIWidget:SetRadioButtonCallbacks(buttons, setting, modUUID)
    for _, button in ipairs(buttons) do
        button.OnChange = function(value)
            if value and button.UserData and button.UserData.OriginalValue ~= nil then
                IMGUIAPI:SetSettingValue(setting:GetId(), button.UserData.OriginalValue, modUUID)
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
        button.Active = button.UserData and button.UserData.OriginalValue == value
    end
end

function RadioIMGUIWidget:GetOnChangeValue(value)
    return value.UserData and value.UserData.OriginalValue or value.Label
end

function RadioIMGUIWidget:SetupTooltip(widget, setting)
    local radioOptions = widget
    local tooltipText = setting:GetTooltip()
    if not tooltipText or tooltipText == "" then
        return
    end
    local tooltipId = setting.Id .. "_TOOLTIP"

    for _, button in ipairs(radioOptions) do
        local tt = IMGUIHelpers.AddTooltip(button, tooltipText, tooltipId)
        if not tt then
            return
        end
    end
end
