---@class ColorPickerIMGUIWidget: IMGUIWidget
ColorPickerIMGUIWidget = _Class:Create("ColorPickerIMGUIWidget", IMGUIWidget)

function ColorPickerIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = ColorPickerIMGUIWidget })
    local rgb = { initialValue[1], initialValue[2], initialValue[3] }
    instance.Widget = group:AddColorPicker("", rgb)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Color, modUUID)
    end
    return instance
end

---@param value vec4
function ColorPickerIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Color = value
end
