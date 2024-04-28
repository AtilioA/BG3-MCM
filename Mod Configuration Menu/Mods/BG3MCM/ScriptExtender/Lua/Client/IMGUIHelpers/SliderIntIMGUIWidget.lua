---@class SliderIntIMGUIWidget: IMGUIWidget
SliderIntIMGUIWidget = _Class:Create("SliderIntIMGUIWidget", IMGUIWidget)

---@return any
function SliderIntIMGUIWidget:CreateWidget(group, widgetName, setting, initialValue, modGUID)
    local slider = group:AddSliderInt(widgetName, initialValue, setting.Options.Min, setting.Options.Max)
    slider.OnChange = function(value)
        IMGUILayer:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return slider
end
