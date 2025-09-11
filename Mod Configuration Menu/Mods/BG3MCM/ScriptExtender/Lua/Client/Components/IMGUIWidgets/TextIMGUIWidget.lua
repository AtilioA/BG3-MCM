---@class TextIMGUIWidget: IMGUIWidget
TextIMGUIWidget = _Class:Create("TextIMGUIWidget", IMGUIWidget)

function TextIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = TextIMGUIWidget })

    instance.Widget = group:AddInputText("", initialValue)
    instance.Widget.OnDeactivate = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Text, modUUID)
    end

    instance.Widget.AutoSelectAll = true

    if setting.Options and setting.Options.Multiline then
        instance.Widget.Multiline = true
    end

    return instance
end

function TextIMGUIWidget:SetupTooltip(widget, setting)
    local tt = IMGUIWidget:SetupTooltip(widget, setting)

    if not tt then
        return
    end

    if not table.isEmpty(tt.Children) then
        local tooltipSeparator = tt:AddSeparator()
        tooltipSeparator:SetColor("Separator", Color.HEXToRGBA("#524444"))
    end

    local localizedText = Ext.Loca.GetTranslatedString("h37e3d35cef6a43468bb71a253982d5634de8")
    tt:AddText(localizedText)
end

function TextIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Text = value
end

function TextIMGUIWidget:GetOnChangeValue(value)
    return value.Text
end
