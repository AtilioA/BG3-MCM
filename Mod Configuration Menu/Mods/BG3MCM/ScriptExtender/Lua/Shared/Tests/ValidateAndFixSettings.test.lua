TestSuite.RegisterTests("ValidateAndFixSettings", {
    "ShouldFixInvalidSettingsAtRootLevel",
    "ShouldFixInvalidSettingInsideTab",
    "ShouldFixInvalidSettingsInsideTab",
    "ShouldFixInvalidSettingInsideTabSection",
    "ShouldKeepValidKeybindingV2WithUppercaseModifier",
    "ShouldKeepValidKeybindingV2WithModifierVariants",
    "ShouldResetInvalidKeybindingV2Modifier",
    "ShouldFixInvalidListV2Setting",
    "ShouldKeepValidListV2Setting",
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

function ShouldKeepValidKeybindingV2WithUppercaseModifier()
    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Settings = {
            BlueprintSetting:New({
                Id = "open_cpf",
                Type = "keybinding_v2",
                Default = {
                    Keyboard = { Key = "INSERT", ModifierKeys = {} },
                    Enabled = true
                }
            })
        }
    })

    local config = {
        ["open_cpf"] = {
            Keyboard = {
                Key = "P",
                ModifierKeys = { "LCTRL" }
            },
            Enabled = true
        }
    }

    local fixedConfig = DataPreprocessing:ValidateAndFixSettings(blueprint, config)

    TestSuite.AssertEquals(fixedConfig["open_cpf"].Keyboard.Key, "P")
    TestSuite.AssertEquals(fixedConfig["open_cpf"].Keyboard.ModifierKeys[1], "LCTRL")
end

function ShouldKeepValidKeybindingV2WithModifierVariants()
    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Settings = {
            BlueprintSetting:New({
                Id = "open_cpf",
                Type = "keybinding_v2",
                Default = {
                    Keyboard = { Key = "INSERT", ModifierKeys = {} },
                    Enabled = true
                }
            })
        }
    })

    local validModifierVariants = { "LCtrl", "lctrl", "LShift", "lshift", "RALT", "none" }

    for _, modifier in ipairs(validModifierVariants) do
        local config = {
            ["open_cpf"] = {
                Keyboard = {
                    Key = "P",
                    ModifierKeys = { modifier }
                },
                Enabled = true
            }
        }

        local fixedConfig = DataPreprocessing:ValidateAndFixSettings(blueprint, config)
        TestSuite.AssertEquals(fixedConfig["open_cpf"].Keyboard.Key, "P")
        TestSuite.AssertEquals(fixedConfig["open_cpf"].Keyboard.ModifierKeys[1], modifier)
    end
end

function ShouldResetInvalidKeybindingV2Modifier()
    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Settings = {
            BlueprintSetting:New({
                Id = "open_cpf",
                Type = "keybinding_v2",
                Default = {
                    Keyboard = { Key = "INSERT", ModifierKeys = {} },
                    Enabled = true
                }
            })
        }
    })

    local config = {
        ["open_cpf"] = {
            Keyboard = {
                Key = "P",
                ModifierKeys = { "LCTRL_BAD" }
            },
            Enabled = true
        }
    }

    local fixedConfig = DataPreprocessing:ValidateAndFixSettings(blueprint, config)

    TestSuite.AssertEquals(fixedConfig["open_cpf"].Keyboard.Key, "INSERT")
    TestSuite.AssertEquals(#fixedConfig["open_cpf"].Keyboard.ModifierKeys, 0)
end

function ShouldFixInvalidListV2Setting()
    local defaultListValue = {
        enabled = true,
        elements = {
            {
                name = "Alpha",
                enabled = true,
            }
        }
    }

    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Settings = {
            BlueprintSetting:New({
                Id = "list-v2-setting",
                Type = "list_v2",
                Default = defaultListValue,
            })
        }
    })

    local config = {
        ["list-v2-setting"] = {
            enabled = "true",
            elements = {
                {
                    name = "Broken",
                    enabled = true,
                }
            }
        }
    }

    local fixedConfig = DataPreprocessing:ValidateAndFixSettings(blueprint, config)

    TestSuite.AssertEquals(fixedConfig["list-v2-setting"], defaultListValue)
end

function ShouldKeepValidListV2Setting()
    local defaultListValue = {
        enabled = false,
        elements = {
            {
                name = "Alpha",
                enabled = false,
            }
        }
    }

    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Settings = {
            BlueprintSetting:New({
                Id = "list-v2-setting",
                Type = "list_v2",
                Default = defaultListValue,
            })
        }
    })

    local validListValue = {
        enabled = true,
        elements = {
            {
                name = "Alpha",
                enabled = true,
            },
            {
                name = "Beta",
                enabled = false,
            }
        }
    }

    local config = {
        ["list-v2-setting"] = validListValue,
    }

    local fixedConfig = DataPreprocessing:ValidateAndFixSettings(blueprint, config)

    TestSuite.AssertEquals(fixedConfig["list-v2-setting"], validListValue)
end
