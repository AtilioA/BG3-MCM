TestSuite.RegisterTests("ValidateAndFixSettings", {
    "ShouldFixInvalidSettingsAtRootLevel",
    "ShouldFixInvalidSettingInsideTab",
    "ShouldFixInvalidSettingsInsideTab",
    "ShouldFixInvalidSettingInsideTabSection",
    "ShouldPreserveDynamicEnumValueWhenChoicesChanged",
})

function ShouldFixInvalidSettingsAtRootLevel()
    -- Create a mock blueprint
    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Settings = {
            BlueprintSetting:New({
                Id = "setting-1",
                Type = "int",
                Default = 42
            }),
            BlueprintSetting:New({
                Id = "setting-2",
                Type = "float",
                Default = 3.14
            }),
            BlueprintSetting:New({
                Id = "setting-3",
                Type = "checkbox",
                Default = true
            })
        }
    })

    -- Create a mock config table with some invalid values
    local config = {
        ["setting-1"] = "invalid1",
        ["setting-2"] = "3.14",
        ["setting-3"] = "false"
    }

    -- Call the ValidateAndFixSettings function
    DataPreprocessing:ValidateAndFixSettings(blueprint, config)

    -- Assert that the config table has been updated with the default values
    TestSuite.AssertEquals(config["setting-1"], 42)
    TestSuite.AssertEquals(config["setting-2"], 3.14)
    TestSuite.AssertEquals(config["setting-3"], true)
end

function ShouldFixInvalidSettingInsideTab()
    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Tabs = {
            BlueprintTab:New({
                TabId = "tab-1",
                TabName = "Tab 1",
                Settings = {
                    BlueprintSetting:New({
                        Id = "setting-1",
                        Type = "float",
                        Default = 3.14
                    }),
                    BlueprintSetting:New({
                        Id = "setting-2",
                        Type = "int",
                        Default = 42
                    }),
                    BlueprintSetting:New({
                        Id = "setting-3",
                        Type = "checkbox",
                        Default = true
                    })
                }
            })
        }
    })

    local config = {
        ["setting-2"] = '42',
    }

    local fixedConfig = DataPreprocessing:ValidateAndFixSettings(blueprint, config)

    TestSuite.AssertEquals(fixedConfig["setting-2"], 42)
end

function ShouldFixInvalidSettingsInsideTab()
    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Tabs = {
            BlueprintTab:New({
                TabId = "tab-1",
                TabName = "Tab 1",
                Settings = {
                    BlueprintSetting:New({
                        Id = "setting-1",
                        Type = "int",
                        Default = 42
                    }),
                    BlueprintSetting:New({
                        Id = "setting-2",
                        Type = "float",
                        Default = 3.14
                    }),
                    BlueprintSetting:New({
                        Id = "setting-3",
                        Type = "checkbox",
                        Default = true
                    })
                }
            })
        }
    })

    local config = {
        ["setting-1"] = "invalid1",
        ["setting-2"] = "invalid2",
        ["setting-3"] = "invalid3"
    }

    DataPreprocessing:ValidateAndFixSettings(blueprint, config)

    TestSuite.AssertEquals(config["setting-1"], 42)
    TestSuite.AssertEquals(config["setting-2"], 3.14)
    TestSuite.AssertEquals(config["setting-3"], true)
end

function ShouldFixInvalidSettingInsideTabSection()
    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Tabs = {
            BlueprintTab:New({
                TabId = "tab-1",
                TabName = "Tab 1",
                Sections = {
                    BlueprintSection:New({
                        SectionId = "section-1",
                        SectionName = "Section 1",
                        Settings = {
                            BlueprintSetting:New({
                                Id = "setting-1",
                                Type = "checkbox",
                                Default = true
                            })
                        }
                    })
                }
            })
        },
    })

    local config = {
        ["setting-1"] = "true",
    }

    local fixedConfig = DataPreprocessing:ValidateAndFixSettings(blueprint, config)

    TestSuite.AssertEquals(fixedConfig["setting-1"], true)
end

function ShouldPreserveDynamicEnumValueWhenChoicesChanged()
    local modUUID = TestConstants.ModuleUUIDs[1]
    local settingId = "setting-dynamic-enum"

    local blueprint = Blueprint:New({
        ModUUID = modUUID,
        SchemaVersion = 1,
        Settings = {
            BlueprintSetting:New({
                Id = settingId,
                Type = "enum",
                Default = "option-1",
                Options = {
                    DynamicChoices = true,
                    Choices = { "option-1", "option-2" }
                }
            })
        }
    })

    local config = {
        [settingId] = "stale-option"
    }

    MCMSettingRuntimeRegistry:SetChoices(modUUID, settingId, { "option-2" })

    local fixedConfig = DataPreprocessing:ValidateAndFixSettings(blueprint, config)
    TestSuite.AssertEquals(fixedConfig[settingId], "stale-option")

    MCMSettingRuntimeRegistry:ResetChoices(modUUID, settingId)
end
