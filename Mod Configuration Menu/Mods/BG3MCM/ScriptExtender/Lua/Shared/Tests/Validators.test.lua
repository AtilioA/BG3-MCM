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
    "TestValidateKeybindingV2Mouse",
    "TestValidateKeybindingV2XOR",
    "TestValidateDynamicEnumPreservesStaleValueDuringLoad",
    "TestValidateDynamicEnumAllowEmptyValue",
    "TestValidateSettingWithCustomValidator",
    "TestRegisterCustomValidatorOnlyOnce",
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
        Keyboard = { Key = "", ModifierKeys = {} },
        Enabled = true
    })
    TestSuite.AssertTrue(isValid)
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

function TestValidateDynamicEnumPreservesStaleValueDuringLoad()
    local modUUID = TestConstants.ModuleUUIDs[1]
    local settingId = "test-dynamic-enum-preserve"
    local setting = BlueprintSetting:New({
        Id = settingId,
        Type = "enum",
        Default = "option-1",
        Options = {
            DynamicChoices = true,
            Choices = { "option-1", "option-2" }
        }
    })

    MCMSettingRuntimeRegistry:SetChoices(modUUID, settingId, { "option-2" })

    local isValid = DataPreprocessing:ValidateSetting(setting, "option-1", {
        modUUID = modUUID,
        allowStaleDynamicChoice = true,
    })
    TestSuite.AssertTrue(isValid)

    isValid = DataPreprocessing:ValidateSetting(setting, "option-1", {
        modUUID = modUUID,
    })
    TestSuite.AssertFalse(isValid)

    MCMSettingRuntimeRegistry:ResetChoices(modUUID, settingId)
end

function TestValidateDynamicEnumAllowEmptyValue()
    local modUUID = TestConstants.ModuleUUIDs[1]
    local settingId = "test-dynamic-enum-empty"
    local setting = BlueprintSetting:New({
        Id = settingId,
        Type = "enum",
        Default = "",
        Options = {
            DynamicChoices = true,
            AllowEmptyValue = true,
            Choices = {}
        }
    })

    MCMSettingRuntimeRegistry:SetChoices(modUUID, settingId, {})

    local isValid = DataPreprocessing:ValidateSetting(setting, "", {
        modUUID = modUUID,
    })
    TestSuite.AssertTrue(isValid)

    isValid = DataPreprocessing:ValidateSetting(setting, "option-1", {
        modUUID = modUUID,
    })
    TestSuite.AssertFalse(isValid)

    MCMSettingRuntimeRegistry:ResetChoices(modUUID, settingId)
end

function TestValidateSettingWithCustomValidator()
    local modUUID = TestConstants.ModuleUUIDs[1]
    local settingId = "test-custom-validator"
    local setting = BlueprintSetting:New({
        Id = settingId,
        Type = "text",
        Default = "default"
    })

    MCMSettingRuntimeRegistry:RegisterValidator(modUUID, settingId, function(value)
        if value == "blocked" then
            return false, "blocked value"
        end
        return true
    end)

    local isValid = DataPreprocessing:ValidateSetting(setting, "allowed", { modUUID = modUUID })
    TestSuite.AssertTrue(isValid)

    isValid = DataPreprocessing:ValidateSetting(setting, "blocked", { modUUID = modUUID })
    TestSuite.AssertFalse(isValid)

    MCMSettingRuntimeRegistry:UnregisterValidator(modUUID, settingId)
end

function TestRegisterCustomValidatorOnlyOnce()
    local modUUID = TestConstants.ModuleUUIDs[1]
    local settingId = "test-custom-validator-single-registration"

    local validatorA = function()
        return true
    end

    local validatorB = function()
        return true
    end

    local didRegister = MCMSettingRuntimeRegistry:RegisterValidator(modUUID, settingId, validatorA)
    TestSuite.AssertTrue(didRegister)

    local didRegisterSame = MCMSettingRuntimeRegistry:RegisterValidator(modUUID, settingId, validatorA)
    TestSuite.AssertTrue(didRegisterSame)

    local didRegisterDifferent = MCMSettingRuntimeRegistry:RegisterValidator(modUUID, settingId, validatorB)
    TestSuite.AssertFalse(didRegisterDifferent)

    MCMSettingRuntimeRegistry:UnregisterValidator(modUUID, settingId)
end
