---@class FloatIMGUIWidget: IMGUIWidget
FloatIMGUIWidget = _Class:Create("FloatIMGUIWidget", IMGUIWidget)

---@param group ExtuiGroup
---@param setting BlueprintSetting
---@param initialValue number
---@param modUUID string
---@return FloatIMGUIWidget
function FloatIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = FloatIMGUIWidget })
    instance.Widget = group:AddInputScalar("", initialValue)
    instance.Widget.OnChange = VCTimer:Debounce(200, function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modUUID)
    end)
    return instance
end

function FloatIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end

---@param value { Value: number[] }
---@return number
function FloatIMGUIWidget:GetOnChangeValue(value)
    return value.Value[1]
end
