---@class ColorEditIMGUIWidget: IMGUIWidget
ColorEditIMGUIWidget = _Class:Create("ColorEditIMGUIWidget", IMGUIWidget)

function ColorEditIMGUIWidget:new(group, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = ColorEditIMGUIWidget })
    local rgb = { initialValue[1], initialValue[2], initialValue[3] }
    instance.Widget = group:AddColorEdit("", rgb)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Color, modGUID)
    end
    return instance
end

---@param value vec4
function ColorEditIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Color = value
end
