---@class SliderIntIMGUIWidget: IMGUIWidget
SliderIntIMGUIWidget = _Class:Create("SliderIntIMGUIWidget", IMGUIWidget)

---@return any
function SliderIntIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    local slider = group:AddSliderInt(setting.Name, settingValue, setting.Options.Min, setting.Options.Max)
    slider.OnChange = function(value)
        IMGUILayer:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return slider
end
