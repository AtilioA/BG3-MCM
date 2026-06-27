D.describe("Setting validators", { tags = { "validators", "unit" } }, function()
    D.test("TestValidateIntSetting", function()
        local setting = BlueprintSetting:New({
            Id = "test-int",
            Type = "int",
            Default = 42
        })

        local isValid, message = DataPreprocessing:ValidateSetting(setting, 42)
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateFloatSetting", function()
        local setting = BlueprintSetting:New({
            Id = "test-float",
            Type = "float",
            Default = 3.14,
        })

        local isValid, message = DataPreprocessing:ValidateSetting(setting, 3.14)
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateCheckboxSetting", function()
        local setting = BlueprintSetting:New({
            Id = "test-checkbox",
            Type = "checkbox",
            Default = true,
        })

        local isValid, message = DataPreprocessing:ValidateSetting(setting, true)
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, false)
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, "true")
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, "false")
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, 0)
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, 1)
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateTextSetting", function()
        local setting = BlueprintSetting:New({
            Id = "test-text",
            Type = "text",
            Default = "hello",
        })

        local isValid, message = DataPreprocessing:ValidateSetting(setting, "hello")
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, 42)
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, true)
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, false)
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateEnumSetting", function()
        local setting = BlueprintSetting:New({
            Id = "test-enum",
            Type = "enum",
            Default = "option-1",
            Options = {
                Choices = { "option-1", "option-2", "option-3" }
            }
        })

        local isValid, message = DataPreprocessing:ValidateSetting(setting, "option-1")
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateDynamicEnumSettingWithoutChoices", function()
        local setting = BlueprintSetting:New({
            Id = "test-dynamic-enum",
            Type = "enum",
            Default = "runtime-default",
            Options = {
                Choices = {}
            }
        })

        local isValid = DataPreprocessing:ValidateSetting(setting, "runtime-value")
        D.expect(isValid).toBeTruthy()

        isValid = DataPreprocessing:ValidateSetting(setting, 42)
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateDynamicEnumSettingWithChoices", function()
        local setting = BlueprintSetting:New({
            Id = "test-dynamic-enum-with-choices",
            Type = "enum",
            Default = "No change",
            Options = {
                Dynamic = true,
                Choices = { "No change" }
            }
        })

        local isValid = DataPreprocessing:ValidateSetting(setting, "Karlach AEE")
        D.expect(isValid).toBeTruthy()

        isValid = DataPreprocessing:ValidateSetting(setting, true)
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateRadioSetting", function()
        local setting = BlueprintSetting:New({
            Id = "test-radio",
            Type = "radio",
            Default = "option-1",
            Options = {
                Choices = { "option-1", "option-2", "option-3" }
            }
        })

        local isValid, message = DataPreprocessing:ValidateSetting(setting, "option-1")
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateSliderIntSetting", function()
        local setting = BlueprintSetting:New({
            Id = "test-slider-int",
            Type = "slider_int",
            Default = 50,
            Options = {
                Min = 0,
                Max = 100
            }
        })

        local isValid, message = DataPreprocessing:ValidateSetting(setting, 50)
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, 101)
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateSliderFloatSetting", function()
        local setting = BlueprintSetting:New({
            Id = "test-slider-float",
            Type = "slider_float",
            Default = 3.14,
            Options = {
                Min = 0,
                Max = 10
            }
        })

        local isValid, message = DataPreprocessing:ValidateSetting(setting, 3.14)
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, 3)
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, 10.1)
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateDragIntSetting", function()
        local setting = BlueprintSetting:New({
            Id = "test-drag-int",
            Type = "drag_int",
            Default = 50,
            Options = {
                Min = 0,
                Max = 100
            }
        })

        local isValid, message = DataPreprocessing:ValidateSetting(setting, 50)
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, 101)
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateDragFloatSetting", function()
        local setting = BlueprintSetting:New({
            Id = "test-drag-float",
            Type = "drag_float",
            Default = 3.14,
            Options = {
                Min = 0,
                Max = 10
            }
        })

        local isValid, message = DataPreprocessing:ValidateSetting(setting, 3.14)
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, 3)
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, 10.1)
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateColorPickerSetting", function()
        local setting = BlueprintSetting:New({
            Id = "color-picker",
            Type = "color_picker",
            Default = { 1, 0, 0, 1 }
        })

        local isValid, message = DataPreprocessing:ValidateSetting(setting, { 1, 0, 0, 1 })
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, { 1, 0, 0, 1.1 })
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
        D.expect(isValid).toBeFalsy()

        -- Test non-normalized RGB inputs
        isValid, message = DataPreprocessing:ValidateSetting(setting, { 255, 0, 0, 1 })
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, { 256, 0, 0, 1 })
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, { 2, 2, 2, 1 })
        D.expect(isValid).toBeFalsy()

        -- Test RGB (without alpha) inputs
        isValid, message = DataPreprocessing:ValidateSetting(setting, { 1, 0, 0 })
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, { 255, 0, 0 })
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, { 256, 0, 0 })
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateColorEditSetting", function()
        local setting = BlueprintSetting:New({
            Id = "color-edit",
            Type = "color_edit",
            Default = { 1, 0, 0, 1 }
        })

        local isValid, message = DataPreprocessing:ValidateSetting(setting, { 1, 0, 0, 1 })
        D.expect(isValid).toBeTruthy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, { 1, 0, 0, 1.1 })
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
        D.expect(isValid).toBeFalsy()

        -- Test non-normalized RGB inputs
        isValid, message = DataPreprocessing:ValidateSetting(setting, { 255, 0, 0, 1 })
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, { 256, 0, 0, 1 })
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, { 2, 2, 2, 1 })
        D.expect(isValid).toBeFalsy()

        -- Test RGB (without alpha) inputs
        isValid, message = DataPreprocessing:ValidateSetting(setting, { 1, 0, 0 })
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, { 255, 0, 0 })
        D.expect(isValid).toBeFalsy()

        isValid, message = DataPreprocessing:ValidateSetting(setting, { 256, 0, 0 })
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateKeybindingV2Keyboard", function()
        local setting = BlueprintSetting:New({
            Id = "test-kb-binding",
            Type = "keybinding_v2",
            Default = {
                Keyboard = { Key = "INSERT", ModifierKeys = {} },
                Enabled = true
            }
        })

        local isValid = KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "INSERT", ModifierKeys = {} },
            Enabled = true
        })
        D.expect(isValid).toBeTruthy()

        isValid = KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "A", ModifierKeys = { "LCTRL", "LSHIFT" } },
            Enabled = true
        })
        D.expect(isValid).toBeTruthy()

        isValid = KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "P", ModifierKeys = { "LCtrl", "LShift" } },
            Enabled = true
        })
        D.expect(isValid).toBeTruthy()

        isValid = KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "", ModifierKeys = {} },
            Enabled = true
        })
        D.expect(isValid).toBeTruthy()
    end)

    D.test("TestValidateKeybindingV2KeyboardModifierVariants", function()
        local setting = BlueprintSetting:New({
            Id = "test-kb-binding-variants",
            Type = "keybinding_v2",
            Default = {
                Keyboard = { Key = "INSERT", ModifierKeys = {} },
                Enabled = true
            }
        })

        local validModifierVariants = {
            "LCTRL",
            "LCtrl",
            "lctrl",
            "LSHIFT",
            "LShift",
            "lshift",
            "RALT",
            "ralt",
            "NONE",
            "none",
            "LGUI",
            "lgui",
        }

        for _, modifier in ipairs(validModifierVariants) do
            local isValid = KeybindingV2Validator.Validate(setting, {
                Keyboard = { Key = "P", ModifierKeys = { modifier } },
                Enabled = true
            })
            D.expect(isValid).toBeTruthy()
        end

        local mixedCaseComboIsValid = KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "P", ModifierKeys = { "lctrl", "LShift" } },
            Enabled = true
        })
        D.expect(mixedCaseComboIsValid).toBeTruthy()
    end)

    D.test("TestValidateKeybindingV2MouseModifierVariants", function()
        local setting = BlueprintSetting:New({
            Id = "test-mouse-binding-variants",
            Type = "keybinding_v2",
            Default = {
                Mouse = { Button = 3, ModifierKeys = {} },
                Enabled = true
            }
        })

        local validModifierVariants = {
            "LCTRL",
            "LCtrl",
            "lctrl",
            "LSHIFT",
            "LShift",
            "lshift",
            "RALT",
            "ralt",
            "NONE",
            "none",
        }

        for _, modifier in ipairs(validModifierVariants) do
            local isValid = KeybindingV2Validator.Validate(setting, {
                Mouse = { Button = 3, ModifierKeys = { modifier } },
                Enabled = true
            })
            D.expect(isValid).toBeTruthy()
        end
    end)

    D.test("TestValidateKeybindingV2InvalidModifier", function()
        local setting = BlueprintSetting:New({
            Id = "test-kb-invalid-modifier",
            Type = "keybinding_v2",
            Default = {
                Keyboard = { Key = "INSERT", ModifierKeys = {} },
                Enabled = true
            }
        })

        local isValid = KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "P", ModifierKeys = { "LCTRL_BAD" } },
            Enabled = true
        })

        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateKeybindingV2InvalidModifierVariants", function()
        local setting = BlueprintSetting:New({
            Id = "test-kb-invalid-modifier-variants",
            Type = "keybinding_v2",
            Default = {
                Keyboard = { Key = "INSERT", ModifierKeys = {} },
                Enabled = true
            }
        })

        local invalidModifierVariants = {
            "LCTRL_BAD",
            "CTRL",
            "LeftCtrl",
            "",
            123,
            true,
            {},
        }

        for _, modifier in ipairs(invalidModifierVariants) do
            local keyboardValid = KeybindingV2Validator.Validate(setting, {
                Keyboard = { Key = "P", ModifierKeys = { modifier } },
                Enabled = true
            })
            D.expect(keyboardValid).toBeFalsy()

            local mouseValid = KeybindingV2Validator.Validate(setting, {
                Mouse = { Button = 3, ModifierKeys = { modifier } },
                Enabled = true
            })
            D.expect(mouseValid).toBeFalsy()
        end
    end)

    D.test("TestValidateKeybindingV2Mouse", function()
        local setting = BlueprintSetting:New({
            Id = "test-mouse-binding",
            Type = "keybinding_v2",
            Default = {
                Mouse = { Button = 1, ModifierKeys = {} },
                Enabled = true
            }
        })

        local isValid = KeybindingV2Validator.Validate(setting, {
            Mouse = { Button = 1, ModifierKeys = {} },
            Enabled = true
        })
        D.expect(isValid).toBeTruthy()

        isValid = KeybindingV2Validator.Validate(setting, {
            Mouse = { Button = 3, ModifierKeys = { "LCTRL" } },
            Enabled = true
        })
        D.expect(isValid).toBeTruthy()

        isValid = KeybindingV2Validator.Validate(setting, {
            Mouse = { Button = 10, ModifierKeys = {} },
            Enabled = true
        })
        D.expect(isValid).toBeTruthy()

        isValid = KeybindingV2Validator.Validate(setting, {
            Mouse = { Button = 0, ModifierKeys = {} },
            Enabled = true
        })
        D.expect(isValid).toBeTruthy()

        isValid = KeybindingV2Validator.Validate(setting, {
            Mouse = { Button = 11, ModifierKeys = {} },
            Enabled = true
        })
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateKeybindingV2XOR", function()
        local setting = BlueprintSetting:New({
            Id = "test-xor-binding",
            Type = "keybinding_v2",
            Default = {
                Keyboard = { Key = "INSERT", ModifierKeys = {} },
                Enabled = true
            }
        })

        local isValid = KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "INSERT", ModifierKeys = {} },
            Mouse = { Button = 1, ModifierKeys = {} },
            Enabled = true
        })
        D.expect(isValid).toBeFalsy()

        isValid = KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "", ModifierKeys = {} },
            Mouse = { Button = 1, ModifierKeys = {} },
            Enabled = true
        })
        D.expect(isValid).toBeTruthy()

        isValid = KeybindingV2Validator.Validate(setting, {
            Keyboard = { Key = "A", ModifierKeys = {} },
            Mouse = { Button = 0, ModifierKeys = {} },
            Enabled = true
        })
        D.expect(isValid).toBeTruthy()

        isValid = KeybindingV2Validator.Validate(setting, {
            Enabled = true
        })
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateListV2Setting", function()
        local setting = BlueprintSetting:New({
            Id = "test-list-v2",
            Type = "list_v2",
            Default = {
                enabled = true,
                elements = {}
            }
        })

        local isValid = DataPreprocessing:ValidateSetting(setting, {
            enabled = true,
            elements = {
                {
                    name = "A",
                    enabled = true
                }
            }
        })
        D.expect(isValid).toBeTruthy()

        isValid = DataPreprocessing:ValidateSetting(setting, {
            enabled = "yes",
            elements = {}
        })
        D.expect(isValid).toBeFalsy()

        isValid = DataPreprocessing:ValidateSetting(setting, {
            enabled = true,
            elements = {
                {
                    name = "",
                    enabled = true
                }
            }
        })
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestValidateEventButtonSetting", function()
        local setting = BlueprintSetting:New({
            Id = "test-event-button-setting",
            Type = "event_button"
        })

        local isValid = DataPreprocessing:ValidateSetting(setting, nil)
        D.expect(isValid).toBeTruthy()

        isValid = DataPreprocessing:ValidateSetting(setting, { metadata = "ok" })
        D.expect(isValid).toBeTruthy()

        isValid = DataPreprocessing:ValidateSetting(setting, "invalid")
        D.expect(isValid).toBeFalsy()
    end)

    D.test("TestNonExistentSetting", function()
        local setting = BlueprintSetting:New({
            Id = "non-existent",
            Type = "unknown",
            Default = "unknown",
        })

        local isValid = DataPreprocessing:ValidateSetting(setting, "unknown")
        D.expect(isValid).toBeFalsy()
    end)
end)
