---@class ColorPickerIMGUIWidget: IMGUIWidget
---@field Widget ExtuiColorPicker
ColorPickerIMGUIWidget = _Class:Create("ColorPickerIMGUIWidget", IMGUIWidget)

---@param group ExtuiGroup
---@param setting BlueprintSetting
---@param initialValue RGBAColor
---@param modUUID string
---@return ColorPickerIMGUIWidget
function ColorPickerIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = ColorPickerIMGUIWidget })
    ---@cast instance ColorPickerIMGUIWidget
    local rgb = { initialValue[1], initialValue[2], initialValue[3] }
    instance.Widget = group:AddColorPicker("", rgb)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting:GetId(), value.Color, modUUID)
    end
    return instance
end

---@param value vec4
function ColorPickerIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Color = value
end

---@param value { Color: vec4 }
---@return vec4
function ColorPickerIMGUIWidget:GetOnChangeValue(value)
    return value.Color
end
