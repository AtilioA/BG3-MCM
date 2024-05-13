--- Factory for creating IMGUI widgets based on the type of setting
InputWidgetFactory = {
    int = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, IntIMGUIWidget)
    end,
    float = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, FloatIMGUIWidget)
    end,
    checkbox = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, CheckboxIMGUIWidget)
    end,
    text = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, TextIMGUIWidget)
    end,
    enum = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, EnumIMGUIWidget)
    end,
    slider_int = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, SliderIntIMGUIWidget)
    end,
    slider_float = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, SliderFloatIMGUIWidget)
    end,
    drag_int = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, DragIntIMGUIWidget)
    end,
    drag_float = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, DragFloatIMGUIWidget)
    end,
    radio = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, RadioIMGUIWidget)
    end,
    color_picker = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, ColorPickerIMGUIWidget)
    end,
    color_edit = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, ColorEditIMGUIWidget)
    end,
    keybinding = function(group, setting, settingValue, modGUID)
        return IMGUIWidget:Create(group, setting, settingValue, modGUID, KeybindingIMGUIWidget)
    end,
}

return InputWidgetFactory
