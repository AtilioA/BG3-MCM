---@class ColorPickerIMGUIWidget: IMGUIWidget
ColorPickerIMGUIWidget = _Class:Create("ColorPickerIMGUIWidget", IMGUIWidget)

function ColorPickerIMGUIWidget:new(group, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = ColorPickerIMGUIWidget })
    local rgb = { initialValue[1], initialValue[2], initialValue[3] }
    instance.Widget = group:AddColorPicker("", rgb)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Color, modGUID)
    end
    return instance
end

---@param value vec4
function ColorPickerIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Color = value
end
