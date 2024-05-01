---@class SliderIntIMGUIWidget: IMGUIWidget
SliderIntIMGUIWidget = _Class:Create("SliderIntIMGUIWidget", IMGUIWidget)

---@return any
function SliderIntIMGUIWidget:new(group, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = SliderIntIMGUIWidget })
    instance.Widget = group:AddSliderInt("", initialValue, setting.Options.Min, setting.Options.Max)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return instance
end

function SliderIntIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end
