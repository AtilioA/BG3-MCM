TestSuite.RegisterTests("Validators", {
    "TestSettingEnumDefaultShouldBeOneOfTheOptions",
    "TestSettingRadioDefaultShouldBeOneOfTheOptions",
})

function TestSettingEnumDefaultShouldBeOneOfTheOptions()
    local setting = BlueprintSetting:New({
        Id = "test-setting",
        Type = "enum",
        Default = "invalid",
        Options = { "option-1", "option-2" }
    })

    local isValid, message = DataPreprocessing:ValidateSetting(setting)

    TestSuite.AssertFalse(isValid)
end

function TestSettingRadioDefaultShouldBeOneOfTheOptions()
    local setting = BlueprintSetting:New({
        Id = "test-setting",
        Type = "radio",
        Default = "invalid",
        Options = { "option-1", "option-2" }
    })

    local isValid, message = DataPreprocessing:ValidateSetting(setting)

    TestSuite.AssertFalse(isValid)
end
