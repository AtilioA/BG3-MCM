---@class SliderFloatIMGUIWidget: IMGUIWidget
SliderFloatIMGUIWidget = _Class:Create("SliderFloatIMGUIWidget", IMGUIWidget)

---@return any
function SliderFloatIMGUIWidget:CreateWidget(group, widgetName, setting, initialValue, modGUID)
    local slider = group:AddSlider(widgetName, initialValue, setting.Options.Min, setting.Options.Max)
    slider.OnChange = function(value)
        IMGUIAPI:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return slider
end
