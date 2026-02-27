TestSuite.RegisterTests("Setting validators", {
    "TestValidateIntSetting",
    "TestValidateFloatSetting",
    "TestValidateCheckboxSetting",
    "TestValidateTextSetting",
    "TestValidateEnumSetting",
    "TestValidateRadioSetting",
    "TestValidateSliderIntSetting",
    "TestValidateSliderFloatSetting",
    "TestValidateDragIntSetting",
    "TestValidateDragFloatSetting",
    "TestValidateColorPickerSetting",
    "TestValidateColorEditSetting",
    "TestValidateKeybindingV2Keyboard",
    "TestValidateKeybindingV2KeyboardModifierVariants",
    "TestValidateKeybindingV2MouseModifierVariants",
    "TestValidateKeybindingV2InvalidModifier",
    "TestValidateKeybindingV2InvalidModifierVariants",
    "TestValidateKeybindingV2Mouse",
    "TestValidateKeybindingV2XOR",
})

function TestValidateIntSetting()
    local setting = BlueprintSetting:New({
        Id = "test-int",
        Type = "int",
        Default = 42
    })

    local isValid, message = DataPreprocessing:ValidateSetting(setting, 42)
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
    TestSuite.AssertFalse(isValid)
end

function TestValidateFloatSetting()
    local setting = BlueprintSetting:New({
        Id = "test-float",
        Type = "float",
        Default = 3.14,
    })

    local isValid, message = DataPreprocessing:ValidateSetting(setting, 3.14)
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
    TestSuite.AssertFalse(isValid)
end

function TestValidateCheckboxSetting()
    local setting = BlueprintSetting:New({
        Id = "test-checkbox",
        Type = "checkbox",
        Default = true,
    })

    local isValid, message = DataPreprocessing:ValidateSetting(setting, true)
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, false)
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, "true")
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, "false")
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, 0)
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, 1)
    TestSuite.AssertFalse(isValid)
end

function TestValidateTextSetting()
    local setting = BlueprintSetting:New({
        Id = "test-text",
        Type = "text",
        Default = "hello",
    })

    local isValid, message = DataPreprocessing:ValidateSetting(setting, "hello")
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, 42)
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, true)
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, false)
    TestSuite.AssertFalse(isValid)
end

function TestValidateEnumSetting()
    local setting = BlueprintSetting:New({
        Id = "test-enum",
        Type = "enum",
        Default = "option-1",
        Options = {
            Choices = { "option-1", "option-2", "option-3" }
        }
    })

    local isValid, message = DataPreprocessing:ValidateSetting(setting, "option-1")
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
    TestSuite.AssertFalse(isValid)
end

function TestValidateSliderIntSetting()
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
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, 101)
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
    TestSuite.AssertFalse(isValid)
end

function TestValidateSliderFloatSetting()
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
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, 3)
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, 10.1)
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
    TestSuite.AssertFalse(isValid)
end

function TestValidateDragIntSetting()
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
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, 101)
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
    TestSuite.AssertFalse(isValid)
end

function TestValidateDragFloatSetting()
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
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, 3)
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, 10.1)
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
    TestSuite.AssertFalse(isValid)
end

function TestValidateRadioSetting()
    local setting = BlueprintSetting:New({
        Id = "test-radio",
        Type = "radio",
        Default = "option-1",
        Options = {
            Choices = { "option-1", "option-2", "option-3" }
        }
    })

    local isValid, message = DataPreprocessing:ValidateSetting(setting, "option-1")
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
    TestSuite.AssertFalse(isValid)
end

function TestValidateColorPickerSetting()
    local setting = BlueprintSetting:New({
        Id = "color-picker",
        Type = "color_picker",
        Default = { 1, 0, 0, 1 }
    })

    local isValid, message = DataPreprocessing:ValidateSetting(setting, { 1, 0, 0, 1 })
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, { 1, 0, 0, 1.1 })
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
    TestSuite.AssertFalse(isValid)

    -- Test non-normalized RGB inputs
    isValid, message = DataPreprocessing:ValidateSetting(setting, { 255, 0, 0, 1 })
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, { 256, 0, 0, 1 })
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, { 2, 2, 2, 1 })
    TestSuite.AssertFalse(isValid)

    -- Test RGB (without alpha) inputs
    isValid, message = DataPreprocessing:ValidateSetting(setting, { 1, 0, 0 })
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, { 255, 0, 0 })
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, { 256, 0, 0 })
    TestSuite.AssertFalse(isValid)
end

function TestValidateColorEditSetting()
    local setting = BlueprintSetting:New({
        Id = "color-edit",
        Type = "color_edit",
        Default = { 1, 0, 0, 1 }
    })

    local isValid, message = DataPreprocessing:ValidateSetting(setting, { 1, 0, 0, 1 })
    TestSuite.AssertTrue(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, { 1, 0, 0, 1.1 })
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, "invalid")
    TestSuite.AssertFalse(isValid)

    -- Test non-normalized RGB inputs
    isValid, message = DataPreprocessing:ValidateSetting(setting, { 255, 0, 0, 1 })
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, { 256, 0, 0, 1 })
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, { 2, 2, 2, 1 })
    TestSuite.AssertFalse(isValid)

    -- Test RGB (without alpha) inputs
    isValid, message = DataPreprocessing:ValidateSetting(setting, { 1, 0, 0 })
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, { 255, 0, 0 })
    TestSuite.AssertFalse(isValid)

    isValid, message = DataPreprocessing:ValidateSetting(setting, { 256, 0, 0 })
    TestSuite.AssertFalse(isValid)
end

function TestNonExistentSetting()
    local setting = BlueprintSetting:New({
        Id = "non-existent",
        Type = "unknown",
        Default = "unknown",
    })

    local isValid, message = DataPreprocessing:ValidateSetting(setting, "unknown")
    TestSuite.AssertFalse(isValid)
end

function TestValidateKeybindingV2Keyboard()
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
    TestSuite.AssertTrue(isValid)

    isValid = KeybindingV2Validator.Validate(setting, {
        Keyboard = { Key = "A", ModifierKeys = { "LCTRL", "LSHIFT" } },
        Enabled = true
    })
    TestSuite.AssertTrue(isValid)

    isValid = KeybindingV2Validator.Validate(setting, {
        Keyboard = { Key = "P", ModifierKeys = { "LCtrl", "LShift" } },
        Enabled = true
    })
    TestSuite.AssertTrue(isValid)

    isValid = KeybindingV2Validator.Validate(setting, {
        Keyboard = { Key = "", ModifierKeys = {} },
        Enabled = true
    })
    TestSuite.AssertTrue(isValid)
end

function TestValidateKeybindingV2KeyboardModifierVariants()
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
        TestSuite.AssertTrue(isValid, "Expected valid keyboard modifier variant: " .. tostring(modifier))
    end

    local mixedCaseComboIsValid = KeybindingV2Validator.Validate(setting, {
        Keyboard = { Key = "P", ModifierKeys = { "lctrl", "LShift" } },
        Enabled = true
    })
    TestSuite.AssertTrue(mixedCaseComboIsValid)
end

function TestValidateKeybindingV2MouseModifierVariants()
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
        TestSuite.AssertTrue(isValid, "Expected valid mouse modifier variant: " .. tostring(modifier))
    end
end

function TestValidateKeybindingV2InvalidModifier()
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

    TestSuite.AssertFalse(isValid)
end

function TestValidateKeybindingV2InvalidModifierVariants()
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
        TestSuite.AssertFalse(keyboardValid, "Expected invalid keyboard modifier variant: " .. tostring(modifier))

        local mouseValid = KeybindingV2Validator.Validate(setting, {
            Mouse = { Button = 3, ModifierKeys = { modifier } },
            Enabled = true
        })
        TestSuite.AssertFalse(mouseValid, "Expected invalid mouse modifier variant: " .. tostring(modifier))
    end
end

function TestValidateKeybindingV2Mouse()
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
    TestSuite.AssertTrue(isValid)

    isValid = KeybindingV2Validator.Validate(setting, {
        Mouse = { Button = 3, ModifierKeys = { "LCTRL" } },
        Enabled = true
    })
    TestSuite.AssertTrue(isValid)

    isValid = KeybindingV2Validator.Validate(setting, {
        Mouse = { Button = 10, ModifierKeys = {} },
        Enabled = true
    })
    TestSuite.AssertTrue(isValid)

    isValid = KeybindingV2Validator.Validate(setting, {
        Mouse = { Button = 0, ModifierKeys = {} },
        Enabled = true
    })
    TestSuite.AssertTrue(isValid)

    isValid = KeybindingV2Validator.Validate(setting, {
        Mouse = { Button = 11, ModifierKeys = {} },
        Enabled = true
    })
    TestSuite.AssertFalse(isValid)
end

function TestValidateKeybindingV2XOR()
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
    TestSuite.AssertFalse(isValid)

    isValid = KeybindingV2Validator.Validate(setting, {
        Keyboard = { Key = "", ModifierKeys = {} },
        Mouse = { Button = 1, ModifierKeys = {} },
        Enabled = true
    })
    TestSuite.AssertTrue(isValid)

    isValid = KeybindingV2Validator.Validate(setting, {
        Keyboard = { Key = "A", ModifierKeys = {} },
        Mouse = { Button = 0, ModifierKeys = {} },
        Enabled = true
    })
    TestSuite.AssertTrue(isValid)

    isValid = KeybindingV2Validator.Validate(setting, {
        Enabled = true
    })
    TestSuite.AssertFalse(isValid)
end
