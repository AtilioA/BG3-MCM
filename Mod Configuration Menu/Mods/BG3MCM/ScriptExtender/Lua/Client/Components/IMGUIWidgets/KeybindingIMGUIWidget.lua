---@class KeybindingIMGUIWidget: IMGUIWidget
KeybindingIMGUIWidget = _Class:Create("KeybindingIMGUIWidget", IMGUIWidget)

function KeybindingIMGUIWidget:new(group, setting, initialValue, modUUID)
    local instance = setmetatable({}, { __index = KeybindingIMGUIWidget })

    instance.Widget = {
        Modifier = nil,
        ScanCode = nil
    }

    -- Create the combo box for the modifier
    group:AddText("Modifier (optional)")
    instance.Widget.ModifierWidget = group:AddCombo("", initialValue.Modifier or "")
    instance.Widget.ModifierWidget.IDContext = setting.Id .. "_Modifier"
    instance.Widget.ModifierWidget.Options = SDLKeys.Modifiers

    -- Create the combo box for the scan code
    group:AddText("Key")
    instance.Widget.ScanCodeWidget = group:AddCombo("", initialValue.ScanCode or "")
    instance.Widget.ScanCodeWidget.IDContext = setting.Id .. "_ScanCode"
    instance.Widget.ScanCodeWidget.Options = SDLKeys.ScanCodes

    -- Set initial selection
    for i, value in ipairs(instance.Widget.ModifierWidget.Options) do
        if value == initialValue.Modifier then
            instance.Widget.ModifierWidget.SelectedIndex = i - 1
            break
        end
    end

    for i, value in ipairs(instance.Widget.ScanCodeWidget.Options) do
        if value == initialValue.ScanCode then
            instance.Widget.ScanCodeWidget.SelectedIndex = i - 1
            break
        end
    end

    -- Update the keybinding value when the user changes modifier or scan code
    instance.Widget.ModifierWidget.OnChange = function(value)
        self:UpdateKeybindingValue(
            setting,
            {
                ScanCode = instance.Widget.ScanCodeWidget.Options[instance.Widget.ScanCodeWidget.SelectedIndex + 1],
                Modifier = value
                    .Options[value.SelectedIndex + 1] or "NONE"
            },
            modUUID
        )
    end

    instance.Widget.ScanCodeWidget.OnChange = function(value)
        self:UpdateKeybindingValue(
            setting,
            {
                ScanCode = value.Options[value.SelectedIndex + 1],
                Modifier = instance.Widget.ModifierWidget.Options
                    [instance.Widget.ModifierWidget.SelectedIndex + 1] or "NONE"
            },
            modUUID
        )
    end

    return instance
end

function KeybindingIMGUIWidget:UpdateCurrentValue(value)
    for i, option in ipairs(self.Widget.ModifierWidget.Options) do
        if option == value.Modifier then
            self.Widget.ModifierWidget.SelectedIndex = i - 1
            break
        end
    end

    for i, option in ipairs(self.Widget.ScanCodeWidget.Options) do
        if option == value.ScanCode then
            self.Widget.ScanCodeWidget.SelectedIndex = i - 1
            break
        end
    end
end

function KeybindingIMGUIWidget:UpdateKeybindingValue(setting, newValue, modUUID)
    IMGUIAPI:SetSettingValue(setting.Id, newValue, modUUID)
end
