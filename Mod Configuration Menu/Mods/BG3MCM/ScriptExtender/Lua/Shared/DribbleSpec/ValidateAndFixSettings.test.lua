D.describe("ValidateAndFixSettings", { tags = { "validate-and-fix", "unit" } }, function()
    D.test("ShouldFixInvalidSettingsAtRootLevel", function()
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
        D.expect(config["setting-1"]).toBe(42)
        D.expect(config["setting-2"]).toBe(3.14)
        D.expect(config["setting-3"]).toBe(true)
    end)

    D.test("ShouldFixInvalidSettingInsideTab", function()
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

        D.expect(fixedConfig["setting-2"]).toBe(42)
    end)

    D.test("ShouldFixInvalidSettingsInsideTab", function()
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

        D.expect(config["setting-1"]).toBe(42)
        D.expect(config["setting-2"]).toBe(3.14)
        D.expect(config["setting-3"]).toBe(true)
    end)

    D.test("ShouldFixInvalidSettingInsideTabSection", function()
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

        D.expect(fixedConfig["setting-1"]).toBe(true)
    end)

    D.test("ShouldKeepValidKeybindingV2WithUppercaseModifier", function()
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

        D.expect(fixedConfig["open_cpf"].Keyboard.Key).toBe("P")
        D.expect(fixedConfig["open_cpf"].Keyboard.ModifierKeys[1]).toBe("LCTRL")
    end)

    D.test("ShouldKeepValidKeybindingV2WithModifierVariants", function()
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
            D.expect(fixedConfig["open_cpf"].Keyboard.Key).toBe("P")
            D.expect(fixedConfig["open_cpf"].Keyboard.ModifierKeys[1]).toBe(modifier)
        end
    end)

    D.test("ShouldResetInvalidKeybindingV2Modifier", function()
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

        D.expect(fixedConfig["open_cpf"].Keyboard.Key).toBe("INSERT")
        D.expect(#fixedConfig["open_cpf"].Keyboard.ModifierKeys).toBe(0)
    end)

    D.test("ShouldFixInvalidListV2Setting", function()
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

        D.expect(fixedConfig["list-v2-setting"]).toBe(defaultListValue)
    end)

    D.test("ShouldKeepValidListV2Setting", function()
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

        D.expect(fixedConfig["list-v2-setting"]).toBe(validListValue)
    end)

    D.test("ShouldKeepDynamicEnumStringValueUntilChoicesAreInjected", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                BlueprintSetting:New({
                    Id = "dynamic-enum",
                    Type = "enum",
                    Default = "runtime-default",
                    Options = {
                        Choices = {}
                    }
                })
            }
        })

        local config = {
            ["dynamic-enum"] = "manually-edited-value"
        }

        local fixedConfig = DataPreprocessing:ValidateAndFixSettings(blueprint, config)

        D.expect(fixedConfig["dynamic-enum"]).toBe("manually-edited-value")
    end)

    D.test("ShouldKeepDynamicEnumStringValueWithChoicesWhenMarkedDynamic", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                BlueprintSetting:New({
                    Id = "preset_karlach",
                    Type = "enum",
                    Default = "No change",
                    Options = {
                        Dynamic = true,
                        Choices = { "No change" }
                    }
                })
            }
        })

        local config = {
            ["preset_karlach"] = "Karlach AEE"
        }

        local fixedConfig = DataPreprocessing:ValidateAndFixSettings(blueprint, config)

        D.expect(fixedConfig["preset_karlach"]).toBe("Karlach AEE")
    end)
end)
