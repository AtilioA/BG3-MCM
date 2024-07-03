---@class SliderFloatIMGUIWidget: IMGUIWidget
SliderFloatIMGUIWidget = _Class:Create("SliderFloatIMGUIWidget", IMGUIWidget)

function SliderFloatIMGUIWidget:new(group, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = SliderFloatIMGUIWidget })
    instance.Widget = group:AddSlider("", initialValue, setting.Options.Min, setting.Options.Max)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modGUID)
    end
    return instance
end

function SliderFloatIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end

function SliderFloatIMGUIWidget:SetupTooltip(widget, setting)
    -- Call the base class method first
    IMGUIWidget.SetupTooltip(self, widget, setting)

    local tooltip = widget:Tooltip()
    tooltip:AddText(string.format("Min: %.2f", setting.Options.Min))
    tooltip:AddText(string.format("Max: %.2f", setting.Options.Max))
    if not table.isEmpty(tooltip.Children) then
        local tooltipSeparator = tooltip:AddSeparator()
        tooltipSeparator:SetColor("Separator", Color.HEXToRGBA("#524444"))
    end
    tooltip:AddText("CTRL + click to input value manually.")
end
