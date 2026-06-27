local function preprocessAndSanitize(rawData, modUUID)
    local preprocessedData = DataPreprocessing:PreprocessData(rawData, modUUID)
    if not preprocessedData then
        return nil, nil
    end

    local blueprint = Blueprint:New(preprocessedData)
    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
    return sanitizedBlueprint, blueprint
end

D.describe("DataPreprocessing", { tags = { "data-preprocessing", "unit" } }, function()
    D.test("TestSanitizeBlueprintWithSchemaVersion", function()
        local rawData = {
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-1",
                    Name = "Setting 1",
                    Type = "checkbox",
                    Default = true,
                },
            },
        }
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = preprocessAndSanitize(rawData, modUUID)

        D.expect(sanitizedBlueprint).Not.toBeNil()
    end)

    D.test("TestSanitizeBlueprintWithoutSchemaVersion", function()
        local rawData = {}
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = preprocessAndSanitize(rawData, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintAllowsTopLevelSections", function()
        local rawData = {
            SchemaVersion = 1,
            Sections = {
                {
                    SectionId = "section-1",
                    SectionName = "Section 1",
                    Settings = {
                        {
                            Id = "setting-1",
                            Name = "Setting 1",
                            Type = "checkbox",
                            Default = true,
                        }
                    }
                }
            }
        }
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = preprocessAndSanitize(rawData, modUUID)

        D.expect(sanitizedBlueprint).Not.toBeNil()
        D.expect(sanitizedBlueprint:GetAllSettings()["setting-1"]).Not.toBeNil()
    end)

    D.test("TestBlueprintAllowsNoSettings", function()
        local rawData = {
            SchemaVersion = 1,
        }
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = preprocessAndSanitize(rawData, modUUID)

        D.expect(sanitizedBlueprint).Not.toBeNil()
        D.expect(BlueprintShape:HasAnySettings(sanitizedBlueprint)).toBeFalsy()
    end)

    D.test("TestBlueprintShouldHaveTabsOrSettings", function()
        local modUUID = TestConstants.ModuleUUIDs[1]

        local rawDataWithTabs = {
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                    TabName = "Main",
                    Settings = {
                        {
                            Id = "setting-1",
                            Name = "Setting 1",
                            Type = "checkbox",
                            Default = true,
                        }
                    }
                },
            },
        }

        local rawDataWithSettings = {
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-1",
                    Name = "Setting 1",
                    Type = "checkbox",
                    Default = true,
                },
            }
        }

        local sanitizedBlueprint1 = preprocessAndSanitize(rawDataWithTabs, modUUID)
        local sanitizedBlueprint2 = preprocessAndSanitize(rawDataWithSettings, modUUID)

        D.expect(sanitizedBlueprint1).Not.toBeNil()
        D.expect(sanitizedBlueprint2).Not.toBeNil()
    end)

    D.test("TestRootSettingsBlueprintIsValidThroughUsualPath", function()
        local modUUID = TestConstants.ModuleUUIDs[1]
        local rawData = {
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "CheckboxSetting",
                    Name = "Checkbox Setting",
                    Type = "checkbox",
                    Default = true,
                    Tooltip = "This is a checkbox setting.",
                    Description = "This setting can be toggled on or off."
                }
            }
        }

        local sanitizedBlueprint, blueprint = preprocessAndSanitize(rawData, modUUID)
        D.expect(sanitizedBlueprint).Not.toBeNil()
        D.expect(#blueprint:GetSettings()).toBe(1)
        D.expect(blueprint:GetSettings()[1]:GetId()).toBe("CheckboxSetting")
    end)

    D.test("TestBlueprintCanAddRootLevelSettingWithoutTabs", function()
        local modUUID = TestConstants.ModuleUUIDs[1]
        local rawData = {
            SchemaVersion = 1,
            Settings = {}
        }

        local _sanitizedBlueprint, blueprint = preprocessAndSanitize(rawData, modUUID)
        D.expect(blueprint).Not.toBeNil()

        blueprint:AddSetting({
            Id = "root-setting",
            Name = "Root Setting",
            Type = "checkbox",
            Default = true,
        })

        local rootSettings = blueprint:GetSettings()
        D.expect(#rootSettings).toBe(1)
        D.expect(rootSettings[1]:GetId()).toBe("root-setting")

        local allSettings = blueprint:GetAllSettings()
        D.expect(allSettings["root-setting"]).Not.toBeNil()
        D.expect(blueprint:RetrieveDefaultValueForSetting("root-setting") == true).toBeTruthy()

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
        D.expect(sanitizedBlueprint).Not.toBeNil()
    end)

    D.test("TestBlueprintShouldntHaveTabsAndSettings", function()
        local rawData = {
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                    TabName = "Main",
                    Settings = {
                        {
                            Id = "tab-setting-1",
                            Name = "Tab Setting 1",
                            Type = "checkbox",
                            Default = true,
                        }
                    }
                }
            },
            Settings = {
                {
                    Id = "root-setting-1",
                    Name = "Root Setting 1",
                    Type = "checkbox",
                    Default = true,
                }
            }
        }
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = preprocessAndSanitize(rawData, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintShouldHaveSettingsAtSomeLevel", function()
        local allSettingsRootLevel = TestConstants.Blueprints.SettingsRootLevel:GetAllSettings()
        local allSettingsTabLevel = TestConstants.Blueprints.SettingsTabLevel:GetAllSettings()
        local allSettingsSectionLevel = TestConstants.Blueprints.SettingsSectionLevel:GetAllSettings()

        D.expect(next(allSettingsRootLevel) ~= nil).toBeTruthy()
        D.expect(next(allSettingsTabLevel) ~= nil).toBeTruthy()
        D.expect(next(allSettingsSectionLevel) ~= nil).toBeTruthy()
    end)

    D.test("TestBlueprintShapeIncludesNestedTabSettings", function()
        local modUUID = TestConstants.ModuleUUIDs[1]
        local rawData = {
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                    TabName = "Main",
                    Tabs = {
                        {
                            TabId = "nested-tab-1",
                            TabName = "Nested",
                            Settings = {
                                {
                                    Id = "nested-setting",
                                    Name = "Nested Setting",
                                    Type = "checkbox",
                                    Default = true,
                                }
                            }
                        }
                    }
                }
            }
        }

        local blueprint = preprocessAndSanitize(rawData, modUUID)

        D.expect(blueprint).Not.toBeNil()
        D.expect(blueprint:GetAllSettings()["nested-setting"]).Not.toBeNil()
        D.expect(blueprint:RetrieveDefaultValueForSetting("nested-setting")).toBe(true)
    end)

    D.test("TestValidateAndFixSettingsIncludesNestedTabSettings", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                    TabName = "Main",
                    Tabs = {
                        {
                            TabId = "nested-tab-1",
                            TabName = "Nested",
                            Settings = {
                                {
                                    Id = "nested-int",
                                    Name = "Nested Int",
                                    Type = "int",
                                    Default = 7,
                                }
                            }
                        }
                    }
                }
            }
        })

        local config = {
            ["nested-int"] = "broken"
        }

        local fixedConfig = DataPreprocessing:ValidateAndFixSettings(blueprint, config)

        D.expect(fixedConfig["nested-int"]).toBe(7)
    end)

    D.test("TestUniqueTabIds", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                },
                {
                    TabId = "tab-2",
                },
                {
                    TabId = "tab-1",
                },
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestUniqueSectionIds", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                    Sections = {
                        {
                            SectionId = "section-1",
                        },
                        {
                            SectionId = "section-2",
                        },
                        {
                            SectionId = "section-1",
                        },
                    }
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestUniqueSettingIds", function()
        local blueprintWithRepeatedIDAtRootLevel = TestConstants.Blueprints.SettingsRootLevel
        blueprintWithRepeatedIDAtRootLevel.Settings[1].Id = blueprintWithRepeatedIDAtRootLevel.Settings[2].Id

        local blueprintWithRepeatedIDAtTabLevel = TestConstants.Blueprints.SettingsTabLevel
        blueprintWithRepeatedIDAtTabLevel.Tabs[1].Settings[1].Id = blueprintWithRepeatedIDAtTabLevel.Tabs[1].Settings[2]
        .Id

        local blueprintWithRepeatedIDAtSectionLevel = TestConstants.Blueprints.SettingsSectionLevel
        blueprintWithRepeatedIDAtSectionLevel.Tabs[1].Sections[1].Settings[1].Id = blueprintWithRepeatedIDAtSectionLevel
            .Tabs[1].Sections[1].Settings[2].Id

        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprintRoot = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithRepeatedIDAtRootLevel,
            modUUID)
        local sanitizedBlueprintTab = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithRepeatedIDAtTabLevel, modUUID)
        local sanitizedBlueprintSection = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithRepeatedIDAtSectionLevel,
            modUUID)

        D.expect(sanitizedBlueprintRoot).toBeNil()
        D.expect(sanitizedBlueprintTab).toBeNil()
        D.expect(sanitizedBlueprintSection).toBeNil()
    end)

    D.test("TestValidateSettingType", function()
        local blueprint = TestConstants.Blueprints.SettingsRootLevel
        blueprint.Settings[1].Type = "invalid"
        D.expect(TestConstants.validTypes).Not.toContain(blueprint.Settings[1].Type)

        local modUUID = TestConstants.ModuleUUIDs[1]
        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
        D.expect(sanitizedBlueprint).toBeNil()

        ---

        blueprint = TestConstants.Blueprints.SettingsTabLevel
        blueprint.Tabs[1].Settings[1].Type = "invalid"
        D.expect(TestConstants.validTypes).Not.toContain(blueprint.Tabs[1].Settings[1].Type)

        sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
        D.expect(sanitizedBlueprint).toBeNil()

        ---

        blueprint = TestConstants.Blueprints.SettingsSectionLevel
        blueprint.Tabs[1].Sections[1].Settings[1].Type = "invalid"
        D.expect(TestConstants.validTypes).Not.toContain(blueprint.Tabs[1].Sections[1].Settings[1].Type)

        sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintDefaultForIntShouldBeNumber", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-int",
                    Type = "int",
                    Default = "not-a-number"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintDefaultForFloatShouldBeNumber", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-float",
                    Type = "float",
                    Default = "not-a-number"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintDefaultForEnumShouldBeOneOfTheOptions", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-enum",
                    Type = "enum",
                    Options = {
                        "option-1",
                        "option-2",
                        "option-3"
                    },
                    Default = "option-4"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintDefaultForRadioShouldBeOneOfTheOptions", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-radio",
                    Type = "radio",
                    Options = {
                        "option-1",
                        "option-2",
                        "option-3"
                    },
                    Default = "option-4"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintDefaultForCheckboxShouldBeBoolean", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-checkbox",
                    Type = "checkbox",
                    Default = "not-a-boolean"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintDefaultForStringShouldBeString", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-string",
                    Type = "text",
                    Default = 42
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintDefaultForColorShouldBeVec4", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-color",
                    Type = "color_picker",
                    Default = 42
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local correctBlueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-color",
                    Type = "color_picker",
                    Default = { 0, 0, 0, 0 }
                }
            }
        })

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
        local sanitizedCorrectBlueprint = BlueprintPreprocessing:SanitizeBlueprint(correctBlueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
        D.expect(sanitizedCorrectBlueprint).Not.toBeNil()
    end)

    D.test("TestBlueprintDefaultForSliderIntShouldBeInteger", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-slider-int",
                    Type = "slider_int",
                    Options = {
                        Min = 0,
                        Max = 100
                    },
                    Default = 42.5
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintDefaultForSliderFloatShouldBeNumber", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-slider-float",
                    Type = "slider_float",
                    Options = {
                        Min = 0.0,
                        Max = 100.0
                    },
                    Default = "not-a-number"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintDefaultForDragIntShouldBeInteger", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-drag-int",
                    Type = "drag_int",
                    Options = {
                        Min = 0,
                        Max = 100
                    },
                    Default = 42.5
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintDefaultForDragFloatShouldBeNumber", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-drag-float",
                    Type = "drag_float",
                    Options = {
                        Min = 0.0,
                        Max = 100.0
                    },
                    Default = "not-a-number"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintDefaultForSliderShouldBeBetweenMinAndMax", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-slider",
                    Type = "slider_int",
                    Options = {
                        Min = 0,
                        Max = 100
                    },
                    Default = 200
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintDefaultForDragShouldBeBetweenMinAndMax", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-drag",
                    Type = "drag_int",
                    Options = {
                        Min = 0,
                        Max = 100
                    },
                    Default = 200
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("BlueprintShouldHaveOptionsForEnum", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-enum",
                    Type = "enum",
                    Default = "option-1"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("BlueprintShouldAllowEmptyChoicesForDynamicEnum", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-enum",
                    Type = "enum",
                    Options = {
                        Choices = {}
                    },
                    Default = "runtime-value"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).Not.toBeNil()
    end)

    D.test("BlueprintDynamicFlagForEnumShouldBeBoolean", function()
        local invalidBlueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-enum",
                    Type = "enum",
                    Options = {
                        Dynamic = "true",
                        Choices = { "No change" }
                    },
                    Default = "No change"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(invalidBlueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("BlueprintDynamicEnumShouldAllowDefaultOutsideChoices", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-enum",
                    Type = "enum",
                    Options = {
                        Dynamic = true,
                        Choices = { "No change" }
                    },
                    Default = "Runtime Only"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).Not.toBeNil()
    end)

    D.test("BlueprintShouldHaveOptionsForRadio", function()
        local blueprint = Blueprint:New({
            BlueprintSchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-radio",
                    Type = "radio",
                    Default = "option-1"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("BlueprintOptionsForEnumShouldHaveAChoicesArrayOfStrings", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-enum",
                    Type = "enum",
                    Options = {
                        1, 2, 3
                    },
                    Default = "option-1"
                }
            }
        })
        local blueprintWithChoices = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-enum",
                    Type = "enum",
                    Options = {
                        Choices = {
                            1, 2, 3
                        }
                    },
                    Default = "option-1"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
        local sanitizedBlueprintWithChoices = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithChoices, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
        D.expect(sanitizedBlueprintWithChoices).toBeNil()
    end)

    D.test("BlueprintOptionsForRadioShouldHaveAChoicesArrayOfStrings", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-radio",
                    Type = "radio",
                    Options = {
                        1, 2, 3
                    },
                    Default = "option-1"
                }
            }
        })
        local blueprintWithChoices = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-radio",
                    Type = "radio",
                    Options = {
                        Choices = {
                            1, 2, 3
                        }
                    },
                    Default = "option-1"
                }
            }
        })
        local blueprintWithStringChoices = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-radio",
                    Type = "radio",
                    Options = {
                        Choices = {
                            "1", "2", "3"
                        }
                    },
                    Default = "option-1"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
        local sanitizedBlueprintWithChoices = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithChoices, modUUID)
        local sanitizedBlueprintWithStringChoices = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithStringChoices,
            modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
        D.expect(sanitizedBlueprintWithChoices).toBeNil()
        D.expect(sanitizedBlueprintWithStringChoices).Not.toBeNil()
    end)

    D.test("BlueprintShouldHaveMinAndMaxForSlider", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-slider",
                    Type = "slider_int",
                    Default = 50,
                    Options = {
                    }
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("BlueprintMinAndMaxForSliderShouldBeNumbers", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-slider",
                    Type = "slider_int",
                    Default = 50,
                    Options = {
                        Min = "0",
                        Max = "100"
                    }
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("BlueprintMinShouldBeLessThanMaxForSlider", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-slider",
                    Type = "slider_int",
                    Default = 50,
                    Options = {
                        Min = 100,
                        Max = 0
                    }
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintVisibleIfRejectsUnknownSettingId", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "master-toggle",
                    Type = "checkbox",
                    Default = true,
                },
                {
                    Id = "dependent-setting",
                    Type = "text",
                    Default = "ok",
                    VisibleIf = {
                        Conditions = {
                            {
                                SettingId = "missing-setting",
                                Operator = "==",
                                ExpectedValue = true,
                            }
                        }
                    }
                }
            }
        })

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, TestConstants.ModuleUUIDs[1])
        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintVisibleIfAllowsValidCondition", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "master-toggle",
                    Type = "checkbox",
                    Default = true,
                },
                {
                    Id = "dependent-setting",
                    Type = "text",
                    Default = "ok",
                    VisibleIf = {
                        LogicalOperator = "and",
                        Conditions = {
                            {
                                SettingId = "master-toggle",
                                Operator = "==",
                                ExpectedValue = true,
                            }
                        }
                    }
                }
            }
        })

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, TestConstants.ModuleUUIDs[1])
        D.expect(sanitizedBlueprint).Not.toBeNil()
    end)

    D.test("TestBlueprintVisibleIfRejectsEmptyConditionGroup", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "master-toggle",
                    Type = "checkbox",
                    Default = true,
                },
                {
                    Id = "dependent-setting",
                    Type = "text",
                    Default = "ok",
                    VisibleIf = {}
                }
            }
        })

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, TestConstants.ModuleUUIDs[1])
        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintVisibleIfRejectsAdditionalGroupFields", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "master-toggle",
                    Type = "checkbox",
                    Default = true,
                },
                {
                    Id = "dependent-setting",
                    Type = "text",
                    Default = "ok",
                    VisibleIf = {
                        Conditions = {
                            {
                                SettingId = "master-toggle",
                                Operator = "==",
                                ExpectedValue = true,
                            }
                        },
                        ExtraField = true,
                    }
                }
            }
        })

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, TestConstants.ModuleUUIDs[1])
        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintVisibleIfRejectsAdditionalConditionFields", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "master-toggle",
                    Type = "checkbox",
                    Default = true,
                },
                {
                    Id = "dependent-setting",
                    Type = "text",
                    Default = "ok",
                    VisibleIf = {
                        Conditions = {
                            {
                                SettingId = "master-toggle",
                                Operator = "==",
                                ExpectedValue = true,
                                ExtraField = "nope",
                            }
                        }
                    }
                }
            }
        })

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, TestConstants.ModuleUUIDs[1])
        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintVisibleIfAllowsNumberExpectedValue", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "master-toggle",
                    Type = "checkbox",
                    Default = true,
                },
                {
                    Id = "dependent-setting",
                    Type = "text",
                    Default = "ok",
                    VisibleIf = {
                        Conditions = {
                            {
                                SettingId = "master-toggle",
                                Operator = "==",
                                ExpectedValue = 1,
                            }
                        }
                    }
                }
            }
        })

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, TestConstants.ModuleUUIDs[1])
        D.expect(sanitizedBlueprint).Not.toBeNil()
    end)

    D.test("TestBlueprintVisibleIfAllowsRelationalOperatorWithStringExpectedValue", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "master-toggle",
                    Type = "checkbox",
                    Default = true,
                },
                {
                    Id = "dependent-setting",
                    Type = "text",
                    Default = "ok",
                    VisibleIf = {
                        Conditions = {
                            {
                                SettingId = "master-toggle",
                                Operator = ">",
                                ExpectedValue = "1",
                            }
                        }
                    }
                }
            }
        })

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, TestConstants.ModuleUUIDs[1])
        D.expect(sanitizedBlueprint).Not.toBeNil()
    end)

    D.test("TestBlueprintVisibleIfAllowsRelationalOperatorWithBooleanExpectedValue", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "master-toggle",
                    Type = "checkbox",
                    Default = true,
                },
                {
                    Id = "dependent-setting",
                    Type = "text",
                    Default = "ok",
                    VisibleIf = {
                        Conditions = {
                            {
                                SettingId = "master-toggle",
                                Operator = "<=",
                                ExpectedValue = true,
                            }
                        }
                    }
                }
            }
        })

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, TestConstants.ModuleUUIDs[1])
        D.expect(sanitizedBlueprint).Not.toBeNil()
    end)

    D.test("TestBlueprintVisibleIfAllowsRelationalOperatorWithNumberExpectedValue", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "master-toggle",
                    Type = "checkbox",
                    Default = true,
                },
                {
                    Id = "dependent-setting",
                    Type = "text",
                    Default = "ok",
                    VisibleIf = {
                        Conditions = {
                            {
                                SettingId = "master-toggle",
                                Operator = ">=",
                                ExpectedValue = 1,
                            }
                        }
                    }
                }
            }
        })

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, TestConstants.ModuleUUIDs[1])
        D.expect(sanitizedBlueprint).Not.toBeNil()
    end)

    D.test("TestBlueprintVisibleIfRejectsDuplicateConditions", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "master-toggle",
                    Type = "checkbox",
                    Default = true,
                },
                {
                    Id = "dependent-setting",
                    Type = "text",
                    Default = "ok",
                    VisibleIf = {
                        Conditions = {
                            {
                                SettingId = "master-toggle",
                                Operator = "==",
                                ExpectedValue = true,
                            },
                            {
                                SettingId = "master-toggle",
                                Operator = "==",
                                ExpectedValue = true,
                            }
                        }
                    }
                }
            }
        })

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, TestConstants.ModuleUUIDs[1])
        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestBlueprintVisibleIfAllowsValidOrConditionGroup", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "master-toggle",
                    Type = "checkbox",
                    Default = true,
                },
                {
                    Id = "mode",
                    Type = "text",
                    Default = "expert",
                },
                {
                    Id = "dependent-setting",
                    Type = "text",
                    Default = "ok",
                    VisibleIf = {
                        LogicalOperator = "or",
                        Conditions = {
                            {
                                SettingId = "master-toggle",
                                Operator = "==",
                                ExpectedValue = true,
                            },
                            {
                                SettingId = "mode",
                                Operator = "==",
                                ExpectedValue = "expert",
                            }
                        }
                    }
                }
            }
        })

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, TestConstants.ModuleUUIDs[1])
        D.expect(sanitizedBlueprint).Not.toBeNil()
    end)

    D.test("TestBlueprintVisibleIfAllowsValidTabAndSectionConditions", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "main-tab",
                    TabName = "Main",
                    VisibleIf = {
                        Conditions = {
                            {
                                SettingId = "master-toggle",
                                Operator = "==",
                                ExpectedValue = true,
                            }
                        }
                    },
                    Settings = {
                        {
                            Id = "master-toggle",
                            Type = "checkbox",
                            Default = true,
                        }
                    },
                    Sections = {
                        {
                            SectionId = "main-section",
                            SectionName = "Main Section",
                            VisibleIf = {
                                Conditions = {
                                    {
                                        SettingId = "master-toggle",
                                        Operator = "==",
                                        ExpectedValue = true,
                                    }
                                }
                            },
                            Settings = {
                                {
                                    Id = "inner-setting",
                                    Type = "text",
                                    Default = "ok",
                                }
                            }
                        }
                    }
                }
            }
        })

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, TestConstants.ModuleUUIDs[1])
        D.expect(sanitizedBlueprint).Not.toBeNil()
    end)

    D.test("TestKeybindingV2OptionFlagsMustBeBoolean", function()
        local invalidBlueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "kb-setting",
                    Type = "keybinding_v2",
                    Default = {
                        Keyboard = { Key = "A", ModifierKeys = {} },
                        Enabled = true,
                    },
                    Options = {
                        ShouldTriggerOnRepeat = "true",
                    }
                }
            }
        })

        local validBlueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "kb-setting",
                    Type = "keybinding_v2",
                    Default = {
                        Keyboard = { Key = "A", ModifierKeys = {} },
                        Enabled = true,
                    },
                    Options = {
                        ShouldTriggerOnRepeat = true,
                        IsDeveloperOnly = false,
                        ShouldTriggerOnKeyUp = true,
                        ShouldTriggerOnKeyDown = false,
                        BlockIfLevelNotStarted = true,
                        PreventAction = false,
                        SkipCallback = false,
                    }
                }
            }
        })

        local invalidResult = BlueprintPreprocessing:SanitizeBlueprint(invalidBlueprint, TestConstants.ModuleUUIDs[1])
        local validResult = BlueprintPreprocessing:SanitizeBlueprint(validBlueprint, TestConstants.ModuleUUIDs[1])

        D.expect(invalidResult).toBeNil()
        D.expect(validResult).Not.toBeNil()
    end)

    D.test("TestKeybindingV2MouseDefaultButtonBounds", function()
        local validBlueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "kb-mouse-valid",
                    Type = "keybinding_v2",
                    Default = {
                        Mouse = {
                            Button = 1,
                            ModifierKeys = { "LCTRL" },
                        },
                        Enabled = true,
                    }
                }
            }
        })

        local invalidBlueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "kb-mouse-invalid",
                    Type = "keybinding_v2",
                    Default = {
                        Mouse = {
                            Button = 0,
                            ModifierKeys = {},
                        },
                        Enabled = true,
                    }
                }
            }
        })

        local validResult = BlueprintPreprocessing:SanitizeBlueprint(validBlueprint, TestConstants.ModuleUUIDs[1])
        local invalidResult = BlueprintPreprocessing:SanitizeBlueprint(invalidBlueprint, TestConstants.ModuleUUIDs[1])

        D.expect(validResult).Not.toBeNil()
        D.expect(invalidResult).toBeNil()
    end)

    D.test("TestKeybindingV2KeyboardDefaultEmptyModifierNormalizesToNone", function()
        local rawData = {
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "kb-empty-keyboard-modifier",
                    Type = "keybinding_v2",
                    Default = {
                        Keyboard = {
                            Key = "A",
                            ModifierKeys = { "" },
                        },
                        Enabled = true,
                    },
                },
            },
        }

        local sanitizedBlueprint = preprocessAndSanitize(rawData, TestConstants.ModuleUUIDs[1])

        D.expect(sanitizedBlueprint).Not.toBeNil()

        local setting = sanitizedBlueprint:GetSettings()[1]
        local keyboardDefault = setting:GetDefault().Keyboard
        D.expect(keyboardDefault.ModifierKeys[1]).toBe("NONE")
    end)

    D.test("TestKeybindingV2MouseDefaultEmptyModifierNormalizesToNone", function()
        local rawData = {
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "kb-empty-mouse-modifier",
                    Type = "keybinding_v2",
                    Default = {
                        Mouse = {
                            Button = 1,
                            ModifierKeys = { "" },
                        },
                        Enabled = true,
                    },
                },
            },
        }

        local sanitizedBlueprint = preprocessAndSanitize(rawData, TestConstants.ModuleUUIDs[1])

        D.expect(sanitizedBlueprint).Not.toBeNil()

        local setting = sanitizedBlueprint:GetSettings()[1]
        local mouseDefault = setting:GetDefault().Mouse
        D.expect(mouseDefault.ModifierKeys[1]).toBe("NONE")
    end)

    D.test("TestKeybindingV2InvalidModifierStillFailsPreprocessing", function()
        local rawData = {
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "kb-invalid-modifier",
                    Type = "keybinding_v2",
                    Default = {
                        Keyboard = {
                            Key = "A",
                            ModifierKeys = { "LCTRL_BAD" },
                        },
                        Enabled = true,
                    },
                },
            },
        }

        local sanitizedBlueprint = preprocessAndSanitize(rawData, TestConstants.ModuleUUIDs[1])
        D.expect(sanitizedBlueprint).toBeNil()
    end)

    D.test("TestHasSchemaVersionsEntry", function()
        local validData = Blueprint:New({
            SchemaVersion = 1
        })

        local invalidData1 = {}

        local invalidData2 = Blueprint:New({
            SchemaVersion = "1"
        })

        D.expect(BlueprintPreprocessing:HasSchemaVersionsEntry(validData, TestConstants.ModuleUUIDs[1])).toBeTruthy()
        D.expect(BlueprintPreprocessing:HasSchemaVersionsEntry(invalidData1, TestConstants.ModuleUUIDs[1])).toBeFalsy()
        D.expect(BlueprintPreprocessing:HasSchemaVersionsEntry(invalidData2, TestConstants.ModuleUUIDs[1])).toBeFalsy()
    end)

    D.test("TestPreprocessData", function()
        local data = {
            SchemaVersion = 1,
            ModName = "Test Mod",
            Tabs = {
                {
                    TabId = "tab-1",
                    TabName = "Tab 1",
                    Settings = {
                        {
                            Id = "setting-1",
                            Name = "Setting 1",
                            Type = "boolean",
                            Default = true,
                            Description = "Description 1",
                            Tooltip = "Tooltip 1"
                        }
                    },
                    Sections = {
                        {
                            SectionId = "section-1",
                            SectionName = "Section 1",
                            Settings = {
                                {
                                    Id = "setting-2",
                                    Name = "Setting 2",
                                    Type = "number",
                                    Default = 42,
                                    Description = "Description 2",
                                    Tooltip = "Tooltip 2"
                                }
                            }
                        }
                    }
                }
            }
        }

        local preprocessedData = DataPreprocessing:PreprocessData(data, ModuleUUID)

        if preprocessedData == nil then
            error("Preprocessed data is nil")
        end
        D.expect(preprocessedData.SchemaVersion).toBe(1)
        D.expect(preprocessedData.ModName).toBe("Test Mod")
        D.expect(preprocessedData.KeybindingSortMode).toBe(KeybindingSortMode.BLUEPRINT)
        D.expect(preprocessedData.KeybindingSortMode).toBe(KeybindingSortMode.DEFAULT)
        D.expect(#preprocessedData.Tabs).toBe(1)

        local tab = preprocessedData.Tabs[1]
        D.expect(tab.TabId).toBe("tab-1")
        D.expect(tab.TabName).toBe("Tab 1")
        D.expect(#tab.Settings).toBe(1)
        D.expect(#tab.Sections).toBe(1)

        local setting1 = tab.Settings[1]
        D.expect(setting1.Id).toBe("setting-1")
        D.expect(setting1.Name).toBe("Setting 1")
        D.expect(setting1.Type).toBe("boolean")
        D.expect(setting1.Default).toBe(true)
        D.expect(setting1.Description).toBe("Description 1")
        D.expect(setting1.Tooltip).toBe("Tooltip 1")

        local section1 = tab.Sections[1]
        D.expect(section1.SectionId).toBe("section-1")
        D.expect(section1.SectionName).toBe("Section 1")
        D.expect(#section1.Settings).toBe(1)

        local setting2 = section1.Settings[1]
        D.expect(setting2.Id).toBe("setting-2")
        D.expect(setting2.Name).toBe("Setting 2")
        D.expect(setting2.Type).toBe("number")
        D.expect(setting2.Default).toBe(42)
        D.expect(setting2.Description).toBe("Description 2")
        D.expect(setting2.Tooltip).toBe("Tooltip 2")
    end)

    D.test("TestBlueprintDefaultsKeybindingSortMode", function()
        local rawData = {
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-1",
                    Name = "Setting 1",
                    Type = "checkbox",
                    Default = true,
                },
            },
        }
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint, blueprint = preprocessAndSanitize(rawData, modUUID)

        D.expect(sanitizedBlueprint).Not.toBeNil()
        D.expect(blueprint:GetKeybindingSortMode()).toBe(KeybindingSortMode.DEFAULT)
    end)

    D.test("TabsCanHaveEitherTabIdOrId", function()
        local modUUID = TestConstants.ModuleUUIDs[1]

        local rawDataWithTabId = {
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                    TabName = "Tab 1",
                    Settings = {
                        {
                            Id = "setting-1",
                            Name = "Setting 1",
                            Type = "checkbox",
                            Default = true,
                        }
                    }
                }
            }
        }

        local rawDataWithIdAlias = {
            SchemaVersion = 1,
            Tabs = {
                {
                    Id = "tab-2",
                    TabName = "Tab 2",
                    Settings = {
                        {
                            Id = "setting-2",
                            Name = "Setting 2",
                            Type = "checkbox",
                            Default = true,
                        }
                    }
                }
            }
        }

        local rawDataWithoutAnyTabId = {
            SchemaVersion = 1,
            Tabs = {
                {
                    TabName = "Tab 3",
                    Settings = {
                        {
                            Id = "setting-3",
                            Name = "Setting 3",
                            Type = "checkbox",
                            Default = true,
                        }
                    }
                }
            }
        }

        local blueprintWithTabId = Blueprint:New(DataPreprocessing:PreprocessData(rawDataWithTabId, modUUID))
        local blueprintWithIdAlias = Blueprint:New(DataPreprocessing:PreprocessData(rawDataWithIdAlias, modUUID))
        local invalidBlueprint = Blueprint:New(DataPreprocessing:PreprocessData(rawDataWithoutAnyTabId, modUUID))

        local validTab1 = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithTabId, modUUID)
        local validTab2 = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithIdAlias, modUUID)
        local invalidTab = BlueprintPreprocessing:SanitizeBlueprint(invalidBlueprint, modUUID)

        D.expect(validTab1).Not.toBeNil()
        D.expect(validTab2).Not.toBeNil()
        D.expect(blueprintWithIdAlias:GetTabs()[1]:GetId()).toBe("tab-2")
        D.expect(invalidTab).toBeNil()
    end)

    D.test("TabsCanHaveEitherTabNameOrName", function()
        local modUUID = TestConstants.ModuleUUIDs[1]

        local rawDataWithTabName = {
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                    TabName = "Tab 1",
                    Settings = {
                        {
                            Id = "setting-1",
                            Name = "Setting 1",
                            Type = "checkbox",
                            Default = true,
                        }
                    }
                }
            }
        }

        local rawDataWithNameAlias = {
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-2",
                    Name = "Tab 2",
                    Settings = {
                        {
                            Id = "setting-2",
                            Name = "Setting 2",
                            Type = "checkbox",
                            Default = true,
                        }
                    }
                }
            }
        }

        local rawDataWithoutAnyTabName = {
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-3",
                    Settings = {
                        {
                            Id = "setting-3",
                            Name = "Setting 3",
                            Type = "checkbox",
                            Default = true,
                        }
                    }
                }
            }
        }

        local blueprintWithTabName = Blueprint:New(DataPreprocessing:PreprocessData(rawDataWithTabName, modUUID))
        local blueprintWithNameAlias = Blueprint:New(DataPreprocessing:PreprocessData(rawDataWithNameAlias, modUUID))
        local invalidBlueprint = Blueprint:New(DataPreprocessing:PreprocessData(rawDataWithoutAnyTabName, modUUID))

        local validTab1 = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithTabName, modUUID)
        local validTab2 = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithNameAlias, modUUID)
        local invalidTab = BlueprintPreprocessing:SanitizeBlueprint(invalidBlueprint, modUUID)

        D.expect(validTab1).Not.toBeNil()
        D.expect(validTab2).Not.toBeNil()
        D.expect(blueprintWithNameAlias:GetTabs()[1]:GetTabName()).toBe("Tab 2")
        D.expect(invalidTab).toBeNil()
    end)

    D.test("SectionsCanHaveEitherSectionIdOrId", function()
        local validSectionData1 = {
            SectionId = "section-1",
            SectionName = "Section 1"
        }
        local validSectionData2 = {
            Id = "section-2",
            SectionName = "Section 2"
        }
        local invalidSectionData = {
            SectionName = "Section 3"
        }

        local validSection1 = DataPreprocessing:PreprocessSection(validSectionData1, TestConstants.ModuleUUIDs[1])
        local validSection2 = DataPreprocessing:PreprocessSection(validSectionData2, TestConstants.ModuleUUIDs[1])
        local invalidSection = DataPreprocessing:PreprocessSection(invalidSectionData, TestConstants.ModuleUUIDs[1])

        D.expect(validSection1).Not.toBeNil()
        D.expect(validSection2).Not.toBeNil()
        D.expect(invalidSection).toBeNil()
    end)

    D.test("SectionsCanHaveEitherSectionNameOrName", function()
        local validSectionData1 = {
            SectionId = "section-1",
            SectionName = "Section 1"
        }
        local validSectionData2 = {
            Id = "section-2",
            Name = "Section 2"
        }
        local invalidSectionData = {
            SectionId = "section-3"
        }

        local validSection1 = DataPreprocessing:PreprocessSection(validSectionData1, TestConstants.ModuleUUIDs[1])
        local validSection2 = DataPreprocessing:PreprocessSection(validSectionData2, TestConstants.ModuleUUIDs[1])
        local invalidSection = DataPreprocessing:PreprocessSection(invalidSectionData, TestConstants.ModuleUUIDs[1])

        D.expect(validSection1).Not.toBeNil()
        D.expect(validSection2).Not.toBeNil()
        D.expect(invalidSection).toBeNil()
    end)
end)
