---@class SliderFloatIMGUIWidget: IMGUIWidget
SliderFloatIMGUIWidget = _Class:Create("SliderFloatIMGUIWidget", IMGUIWidget)

---@return any
function SliderFloatIMGUIWidget:CreateWidget(group, setting, settingValue, modGUID)
    local slider = group:AddSlider(setting.Name, settingValue, setting.Options.Min, setting.Options.Max)
    slider.OnChange = function(value)
        IMGUILayer:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return slider
end
