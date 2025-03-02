---@class SliderFloatIMGUIWidget: IMGUIWidget
SliderFloatIMGUIWidget = _Class:Create("SliderFloatIMGUIWidget", IMGUIWidget)

function SliderFloatIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = SliderFloatIMGUIWidget })
    instance.Widget = group:AddSlider("", initialValue, setting.Options.Min, setting.Options.Max)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modUUID)
    end
    return instance
end

function SliderFloatIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end

function SliderFloatIMGUIWidget:SetupTooltip(widget, setting)
    local localizedText = VCString:InterpolateLocalizedMessage("h3914d63b7ccb425f950cea47eca955ad9788",
        string.format("%.2f", setting.Options.Min), string.format("%.2f", setting.Options.Max))

    local tooltipId = setting.Id .. "_TOOLTIP"
    local tt = MCMRendering:AddTooltip(widget, localizedText, tooltipId)

    if not table.isEmpty(tt.Children) then
        local tooltipSeparator = tt:AddSeparator()
        tooltipSeparator:SetColor("Separator", Color.HEXToRGBA("#524444"))
    end

    tt:AddText(Ext.Loca.GetTranslatedString("h0dfee4b6ba51423da77eaa53e1961ade059f"))
end
