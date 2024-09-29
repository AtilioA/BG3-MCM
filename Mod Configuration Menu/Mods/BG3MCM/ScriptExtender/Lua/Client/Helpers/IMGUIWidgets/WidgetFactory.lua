--- 'Factory' for creating IMGUI widgets based on the type of setting
InputWidgetFactory = {
    int = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, IntIMGUIWidget)
    end,
    float = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, FloatIMGUIWidget)
    end,
    checkbox = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, CheckboxIMGUIWidget)
    end,
    text = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, TextIMGUIWidget)
    end,
    list = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, ListIMGUIWidget)
    end,
    list_v2 = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, ListV2IMGUIWidget)
    end,
    enum = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, EnumIMGUIWidget)
    end,
    slider_int = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, SliderIntIMGUIWidget)
    end,
    slider_float = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, SliderFloatIMGUIWidget)
    end,
    drag_int = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, DragIntIMGUIWidget)
    end,
    drag_float = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, DragFloatIMGUIWidget)
    end,
    radio = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, RadioIMGUIWidget)
    end,
    color_picker = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, ColorPickerIMGUIWidget)
    end,
    color_edit = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, ColorEditIMGUIWidget)
    end,
    keybinding = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, KeybindingIMGUIWidget)
    end,
}

return InputWidgetFactory
