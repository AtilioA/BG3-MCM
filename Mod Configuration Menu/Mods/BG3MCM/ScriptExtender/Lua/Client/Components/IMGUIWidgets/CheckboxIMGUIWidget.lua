---@class CheckboxIMGUIWidget: IMGUIWidget
CheckboxIMGUIWidget = _Class:Create("CheckboxIMGUIWidget", IMGUIWidget)

function CheckboxIMGUIWidget:new(group, setting, initialValue, modUUID)
    -- Ensure Widget is an instance-specific property. This is some Lua nonsense that I don't understand. Try designing a better language next time. /hj
    local instance = setmetatable({}, { __index = CheckboxIMGUIWidget })
    instance.Widget = group:AddCheckbox("", initialValue)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Checked, modUUID)
    end
    return instance
end

function CheckboxIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Checked = value
end

function CheckboxIMGUIWidget:GetOnChangeValue(value)
    return value.Checked
end
