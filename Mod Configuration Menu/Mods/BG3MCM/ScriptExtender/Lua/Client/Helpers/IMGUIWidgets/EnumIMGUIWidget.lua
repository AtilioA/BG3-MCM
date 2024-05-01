---@class EnumIMGUIWidget
EnumIMGUIWidget = _Class:Create("EnumIMGUIWidget", IMGUIWidget)

function EnumIMGUIWidget:new(group, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = EnumIMGUIWidget })
    local options = setting.Options.Choices
    instance.Widget = group:AddCombo("", initialValue)
    instance.Widget.Options = options

    -- Set initial selection
    for i, value in ipairs(options) do
        if value == initialValue then
            instance.Widget.SelectedIndex = i - 1
            break
        end
    end

    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, options[value.SelectedIndex + 1], modGUID)
    end

    return instance
end

function EnumIMGUIWidget:UpdateCurrentValue(value)
    for i, option in ipairs(self.Widget.Options) do
        if option == value then
            self.Widget.SelectedIndex = i - 1
            break
        end
    end
end
