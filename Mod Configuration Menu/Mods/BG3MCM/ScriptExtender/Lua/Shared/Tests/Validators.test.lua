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
