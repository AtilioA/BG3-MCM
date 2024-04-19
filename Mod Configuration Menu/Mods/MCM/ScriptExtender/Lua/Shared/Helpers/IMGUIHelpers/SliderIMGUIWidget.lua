---@class SliderIMGUIWidget: IMGUIWidget
SliderIMGUIWidget = _Class:Create("SliderIMGUIWidget", IMGUIWidget)

---@param value number
---@return any
function SliderIMGUIWidget.Create(group, setting, settingValue, modGUID)
    local slider = group:AddSlider(setting.Name, settingValue, setting.Options.Min, setting.Options.Max)
    local tooltip = slider:Tooltip()
    tooltip:AddText(setting.Description)
    slider.OnChange = function(value)
        BG3MCM:SetConfigValue(setting.Id, value.Value[1], modGUID)
    end
    return slider
end
