---@class SliderFloatIMGUIWidget: IMGUIWidget
SliderFloatIMGUIWidget = _Class:Create("SliderFloatIMGUIWidget", IMGUIWidget)

function SliderFloatIMGUIWidget:new(group, widgetName, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = SliderFloatIMGUIWidget })
    instance.Widget = group:AddSlider(widgetName, initialValue, setting.Options.Min, setting.Options.Max)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return instance
end

function SliderFloatIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end
