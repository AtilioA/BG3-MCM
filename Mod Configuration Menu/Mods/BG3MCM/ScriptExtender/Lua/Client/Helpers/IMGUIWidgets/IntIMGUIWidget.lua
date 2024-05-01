---@class IntIMGUIWidget: IMGUIWidget
IntIMGUIWidget = _Class:Create("IntIMGUIWidget", IMGUIWidget)

function IntIMGUIWidget:new(group, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = IntIMGUIWidget })
    instance.Widget = group:AddInputInt("", initialValue)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modGUID)
    end
    return instance
end

function IntIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end
