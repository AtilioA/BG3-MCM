---@class ColorEditIMGUIWidget: IMGUIWidget
ColorEditIMGUIWidget = _Class:Create("ColorEditIMGUIWidget", IMGUIWidget)

---@param group ExtuiGroup
---@param setting BlueprintSetting
---@param initialValue RGBAColor
---@param modUUID string
---@return ColorEditIMGUIWidget
function ColorEditIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = ColorEditIMGUIWidget })
    local rgb = { initialValue[1], initialValue[2], initialValue[3] }
    instance.Widget = group:AddColorEdit("", rgb)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Color, modUUID)
    end
    return instance
end

---@param value vec4
function ColorEditIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Color = value
end

---@param value { Color: RGBAColor }
---@return RGBAColor
function ColorEditIMGUIWidget:GetOnChangeValue(value)
    return value.Color
end
