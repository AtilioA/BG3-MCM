---@class EnumIMGUIWidget
EnumIMGUIWidget = _Class:Create("EnumIMGUIWidget", IMGUIWidget)

local warnedDuplicateLabels = {}

local function warnDuplicateLabelOnce(modUUID, settingId, label)
    local warningKey = tostring(modUUID) .. "::" .. tostring(settingId) .. "::" .. tostring(label)
    if warnedDuplicateLabels[warningKey] then
        return
    end

    warnedDuplicateLabels[warningKey] = true
    MCMWarn(0,
        "Duplicate enum label '" ..
        tostring(label) ..
        "' detected for setting '" ..
        tostring(settingId) ..
        "'. Colliding labels are dropped to avoid ambiguous value mapping.")
end

---@param group any
---@param setting BlueprintSetting
---@param initialValue any
---@param modUUID string
function EnumIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = EnumIMGUIWidget })
    instance._setting = setting
    instance._modUUID = modUUID
    instance._settingId = setting:GetId()
    instance._noOptionsLabel = "No options"

    instance.Widget = group:AddCombo("", initialValue)
    instance.Widget.UserData = {
        OptionsLookup = {},
        HasNoOptions = false,
    }

    instance:UpdateChoices(nil, nil)

    instance:setInitialSelection(initialValue)
    instance:setOnChangeCallback()

    return instance
end

---@param choice string
---@param index integer
---@param useHandles boolean
---@return string
function EnumIMGUIWidget:getDisplayLabel(choice, index, useHandles)
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

---@param choices string[]|nil
---@param isRuntimeOverride boolean
function EnumIMGUIWidget:applyChoices(choices, isRuntimeOverride)
    self.Widget.UserData.OptionsLookup = {}

    local optionsLabels = {}
    local seenLabels = {}
    local useHandles = not isRuntimeOverride

    if type(choices) == "table" then
        for i, value in ipairs(choices) do
            local label = self:getDisplayLabel(value, i, useHandles)
            if seenLabels[label] then
                warnDuplicateLabelOnce(self._modUUID, self._settingId, label)
            else
                seenLabels[label] = true
                table.insert(optionsLabels, label)
                self.Widget.UserData.OptionsLookup[label] = value
            end
        end
    end

    if #optionsLabels == 0 then
        self.Widget.UserData.HasNoOptions = true
        self.Widget.Disabled = true
        self.Widget.Options = { self._noOptionsLabel }
        self.optionsLabels = { self._noOptionsLabel }
        self.Widget.SelectedIndex = 0
        return
    end

    self.Widget.UserData.HasNoOptions = false
    self.Widget.Disabled = false
    self.Widget.Options = optionsLabels
    self.optionsLabels = optionsLabels
end

function EnumIMGUIWidget:setInitialSelection(initialValue)
    if self.Widget.UserData.HasNoOptions then
        self.Widget.SelectedIndex = 0
        return
    end

    for i, value in ipairs(self.optionsLabels) do
        if self.Widget.UserData.OptionsLookup[value] == initialValue then
            self.Widget.SelectedIndex = i - 1
            return
        end
    end

    self.Widget.SelectedIndex = -1
end

function EnumIMGUIWidget:setOnChangeCallback()
    self.Widget.OnChange = function(value)
        if self.Widget.UserData.HasNoOptions then
            return
        end

        local selectedLabel = value.Options[value.SelectedIndex + 1]
        local selectedValue = self.Widget.UserData.OptionsLookup[selectedLabel]
        if selectedValue == nil then
            return
        end

        IMGUIAPI:SetSettingValue(self._setting:GetId(), selectedValue, self._modUUID)
    end
end

function EnumIMGUIWidget:UpdateCurrentValue(value)
    if self.Widget.UserData.HasNoOptions then
        self.Widget.SelectedIndex = 0
        return
    end

    -- Match by the underlying option value
    for i, label in ipairs(self.optionsLabels) do
        if self.Widget.UserData.OptionsLookup[label] == value then
            self.Widget.SelectedIndex = i - 1
            return
        end
    end

    self.Widget.SelectedIndex = -1
end

function EnumIMGUIWidget:GetOnChangeValue(value)
    if self.Widget.UserData.HasNoOptions then
        return nil
    end

    return self.Widget.UserData.OptionsLookup[value.Options[value.SelectedIndex + 1]]
end

---@param choices? string[]
---@param isRuntimeOverride? boolean
---@return boolean
function EnumIMGUIWidget:UpdateChoices(choices, isRuntimeOverride)
    if type(choices) ~= "table" then
        choices, isRuntimeOverride = MCMAPI:GetSettingChoices(self._settingId, self._modUUID)
    end

    self:applyChoices(choices or {}, isRuntimeOverride == true)
    self:setInitialSelection(self._currentValue)
    return true
end
