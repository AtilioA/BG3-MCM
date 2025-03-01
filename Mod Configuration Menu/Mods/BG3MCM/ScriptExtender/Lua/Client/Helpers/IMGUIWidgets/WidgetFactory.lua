local warnedDeprecation = {}

local function warnDeprecation(deprecatedSettingType, modUUID, newType)
    local key = modUUID and (modUUID .. deprecatedSettingType) or deprecatedSettingType
    if warnedDeprecation[key] then return end

    if modUUID then
        local mod = Ext.Mod.GetMod(modUUID)
        if not mod then return MCMWarn(0, "Mod UUID '" .. modUUID .. "' not found") end
        local modInfo = mod.Info
        if not modInfo then return MCMWarn(0, "Mod Info not found for mod UUID '" .. modUUID .. "'") end
        MCMDeprecation(0,
            "Mod '" .. modInfo.Name .. "' is using deprecated '" .. deprecatedSettingType .. "' setting type. " ..
            "Please contact " .. modInfo.Author .. " to update to '" .. newType .. "'.")
    else
        MCMDeprecation(0,
            "Mod is using deprecated '" .. deprecatedSettingType .. "' setting type. " ..
            "Please update usage to '" .. newType .. "'.")
    end

    warnedDeprecation[key] = true
end

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
        warnDeprecation("list", modUUID, "list_v2")
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
        warnDeprecation("keybinding", modUUID, "keybinding_v2")
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, KeybindingIMGUIWidget)
    end,
    keybinding_v2 = function(group, setting, settingValue, modUUID)
        return IMGUIWidget:Create(group, setting, settingValue, modUUID, KeybindingV2IMGUIWidget)
    end,
    default = nil
}

return InputWidgetFactory
