---@class RadioIMGUIWidget: IMGUIWidget
RadioIMGUIWidget = _Class:Create("RadioIMGUIWidget", IMGUIWidget)

local warnedDuplicateLabels = {}

local function warnDuplicateLabelOnce(modUUID, settingId, label)
    local warningKey = tostring(modUUID) .. "::" .. tostring(settingId) .. "::" .. tostring(label)
    if warnedDuplicateLabels[warningKey] then
        return
    end

    warnedDuplicateLabels[warningKey] = true
    MCMWarn(0,
        "Duplicate radio label '" ..
        tostring(label) ..
        "' detected for setting '" ..
        tostring(settingId) ..
        "'. Colliding labels are dropped to avoid ambiguous value mapping.")
end

function RadioIMGUIWidget:new(group, setting, initialValue, modUUID)
    if not group or not setting or not modUUID then
        return {}
    end

    local instance = setmetatable({}, { __index = RadioIMGUIWidget })
    instance._group = group
    instance._setting = setting
    instance._modUUID = modUUID
    instance._settingId = setting:GetId()
    instance._noOptionsLabel = "No options"
    instance._buttonValues = {}
    instance.Widget = {}

    instance:UpdateChoices(nil, nil)
    instance:UpdateCurrentValue(initialValue)

    return instance
end

---@param choice string
---@param index integer
---@param useHandles boolean
---@return string
function RadioIMGUIWidget:GetDisplayLabel(choice, index, useHandles)
    if not useHandles then
        return choice
    end

    local settingHandles = self._setting:GetHandles()
    if settingHandles and settingHandles.ChoicesHandles then
        local localizedValue = Ext.Loca.GetTranslatedString(settingHandles.ChoicesHandles[index])
        if localizedValue and localizedValue ~= "" then
            return localizedValue
        end
    end

    return choice
end

---@param group any The IMGUI group to add the radio buttons to
---@param choices string[] The choice values
---@param isRuntimeOverride boolean
---@param currentValue any The current selected value
---@return table
function RadioIMGUIWidget:CreateRadioButtons(group, choices, isRuntimeOverride, currentValue)
    local buttons = {}

    self._buttonValues = {}

    local seenLabels = {}
    local useHandles = not isRuntimeOverride
    local displayChoices = {}

    if type(choices) == "table" then
        for i, choice in ipairs(choices) do
            local label = self:GetDisplayLabel(choice, i, useHandles)
            if seenLabels[label] then
                warnDuplicateLabelOnce(self._modUUID, self._settingId, label)
            else
                seenLabels[label] = true
                table.insert(displayChoices, {
                    label = label,
                    value = choice,
                })
            end
        end
    end

    if #displayChoices == 0 then
        local noOptionsButton = group:AddRadioButton(self._noOptionsLabel, false)
        noOptionsButton.Disabled = true
        noOptionsButton.IDContext = string.format("radioButton_%s_no_options", self._settingId)
        table.insert(buttons, noOptionsButton)
        return buttons
    end

    for i, entry in ipairs(displayChoices) do
        local isActive = entry.value == currentValue
        local radioButton = group:AddRadioButton(entry.label, isActive)
        radioButton.IDContext = string.format("radioButton_%s_%s", self._settingId, i)
        if i > 1 then
            radioButton.SameLine = true
        end

        self._buttonValues[radioButton] = entry.value
        table.insert(buttons, radioButton)
    end

    return buttons
end

---@param buttons table The radio buttons to set callbacks for
function RadioIMGUIWidget:SetRadioButtonCallbacks(buttons)
    for _, button in ipairs(buttons) do
        local selectedValue = self._buttonValues[button]
        if selectedValue == nil then
            button.OnChange = nil
            goto continue
        end

        button.OnChange = function(value)
            if value and value.Label then
                IMGUIAPI:SetSettingValue(self._settingId, selectedValue, self._modUUID)
                self:UncheckOtherRadioButtons(buttons, button)
            end
        end

        ::continue::
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
        local mappedValue = self._buttonValues[button]
        button.Active = mappedValue ~= nil and mappedValue == value
    end
end

function RadioIMGUIWidget:GetOnChangeValue(value)
    return self._buttonValues[value]
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

function RadioIMGUIWidget:DestroyRadioButtons()
    for _, button in ipairs(self.Widget or {}) do
        xpcall(function()
            button:Destroy()
        end, function() end)
    end
end

---@param choices? string[]
---@param isRuntimeOverride? boolean
---@return boolean
function RadioIMGUIWidget:UpdateChoices(choices, isRuntimeOverride)
    if type(choices) ~= "table" then
        choices, isRuntimeOverride = MCMAPI:GetSettingChoices(self._settingId, self._modUUID)
    end

    self:DestroyRadioButtons()
    self.Widget = self:CreateRadioButtons(self._group, choices or {}, isRuntimeOverride == true, self._currentValue)
    self:SetRadioButtonCallbacks(self.Widget)
    self:SetupTooltip(self.Widget, self._setting)
    self:UpdateCurrentValue(self._currentValue)
    return true
end
