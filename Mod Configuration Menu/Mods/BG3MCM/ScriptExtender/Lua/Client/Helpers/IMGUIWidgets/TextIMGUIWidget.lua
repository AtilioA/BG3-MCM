---@class TextIMGUIWidget: IMGUIWidget
TextIMGUIWidget = _Class:Create("TextIMGUIWidget", IMGUIWidget)

function TextIMGUIWidget:new(group, setting, initialValue, modGUID)
    local instance = setmetatable({}, { __index = TextIMGUIWidget })

    instance.Widget = group:AddInputText("", initialValue)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Text, modGUID)
    end

    instance.Widget.AutoSelectAll = true

    if setting.Options and setting.Options.Multiline then
        instance.Widget.Multiline = true
    end

    return instance
end

function TextIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Text = value
end
