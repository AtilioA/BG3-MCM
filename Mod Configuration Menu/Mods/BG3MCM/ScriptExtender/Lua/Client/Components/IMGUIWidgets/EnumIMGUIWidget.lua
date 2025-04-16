---@class EnumIMGUIWidget
EnumIMGUIWidget = _Class:Create("EnumIMGUIWidget", IMGUIWidget)

---@param group any
---@param setting BlueprintSetting
---@param initialValue any
---@param modUUID string
function EnumIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = EnumIMGUIWidget })
    instance.Widget = group:AddCombo("", initialValue)
    instance.Widget.UserData = {
        OptionsLookup = {}
    }
    instance.optionsLabels = instance:createOptionLabels(setting)
    instance.Widget.Options = instance.optionsLabels

    instance:setInitialSelection(initialValue)
    instance:setOnChangeCallback(setting, modUUID)

    return instance
end

function EnumIMGUIWidget:createOptionLabels(setting)
    local options = setting:GetOptions().Choices
    local optionsLabels = {}
    for i, value in ipairs(options) do
        local localizedValue = self:getLocalizedValue(setting, i)
        table.insert(optionsLabels, localizedValue)
        self.Widget.UserData.OptionsLookup[localizedValue] = value
    end
    return optionsLabels
end

function EnumIMGUIWidget:getLocalizedValue(setting, index)
    local settingHandles = setting:GetHandles()
    if settingHandles and settingHandles.ChoicesHandles then
        -- This might sound weird, but that's because the handles must be ordered in the same way as the choices.
        local localizedValue = Ext.Loca.GetTranslatedString(settingHandles.ChoicesHandles[index])
        if localizedValue and localizedValue ~= "" then
            return localizedValue
        end
    end
    return setting:GetOptions().Choices[index]
end

function EnumIMGUIWidget:setInitialSelection(initialValue)
    for i, value in ipairs(self.optionsLabels) do
        if self.Widget.UserData.OptionsLookup[value] == initialValue then
            self.Widget.SelectedIndex = i - 1
            break
        end
    end
end

function EnumIMGUIWidget:setOnChangeCallback(setting, modUUID)
    self.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting:GetId(),
            self.Widget.UserData.OptionsLookup[value.Options[value.SelectedIndex + 1]], modUUID)
    end
end

function EnumIMGUIWidget:UpdateCurrentValue(value)
    for i, option in ipairs(self.Widget.Options) do
        if option == value then
            self.Widget.SelectedIndex = i - 1
            break
        end
    end
end

function EnumIMGUIWidget:GetOnChangeValue(value)
    return self.Widget.UserData.OptionsLookup[value.Options[value.SelectedIndex + 1]]
end
