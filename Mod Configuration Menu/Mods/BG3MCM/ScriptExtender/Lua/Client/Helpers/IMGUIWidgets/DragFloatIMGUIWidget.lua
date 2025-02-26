---@class DragFloatIMGUIWidget: IMGUIWidget
DragFloatIMGUIWidget = _Class:Create("DragFloatIMGUIWidget", IMGUIWidget)

function DragFloatIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = DragFloatIMGUIWidget })
    instance.Widget = group:AddDrag("", initialValue, setting.Options.Min, setting.Options.Max)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Value[1], modUUID)
    end
    return instance
end

function DragFloatIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Value = { value, value, value, value }
end

function DragFloatIMGUIWidget:SetupTooltip(widget, setting)
    local tt = IMGUILayer:AddTooltip(widget, string.format("Min: %.2f", setting.Options.Min), setting.Id .. "_TOOLTIP")
    tt:AddText(string.format("Max: %.2f", setting.Options.Max))
    if not table.isEmpty(tt.Children) then
        local tooltipSeparator = tt:AddSeparator()
        tooltipSeparator:SetColor("Separator", Color.HEXToRGBA("#524444"))
    end
    tt:AddText("CTRL + click to input value manually.")
end
