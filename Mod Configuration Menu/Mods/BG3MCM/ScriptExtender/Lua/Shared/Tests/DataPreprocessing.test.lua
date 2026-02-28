TestSuite.RegisterTests("DataPreprocessing", {
    -- Blueprint structure validation
    "TestSanitizeBlueprintWithSchemaVersion",
    "TestSanitizeBlueprintWithoutSchemaVersion",
    "TestBlueprintShouldntHaveSections",
    "TestBlueprintShouldntHaveTabsAndSettings",
    "TestBlueprintShouldHaveTabsOrSettings",
    "TestBlueprintCanAddRootLevelSettingWithoutTabs",
    "TestRootSettingsBlueprintIsValidThroughUsualPath",
    "TestBlueprintShouldHaveSettingsAtSomeLevel",
    "TestHasSchemaVersionsEntry",
    "TestPreprocessData",
    "TabsCanHaveEitherTabIdOrId",
    "TabsCanHaveEitherTabNameOrName",
    "SectionsCanHaveEitherSectionIdOrId",
    "SectionsCanHaveEitherSectionNameOrName",

    --- Blueprint integrity validation
    -- IDs
    "TestUniqueTabIds",
    "TestUniqueSectionIds",
    "TestUniqueSettingIds",
    --- Setting definition validation
    -- Type
    "TestValidateSettingType",
    -- Default values
    "TestBlueprintDefaultForIntShouldBeNumber",
    "TestBlueprintDefaultForFloatShouldBeNumber",
    "TestBlueprintDefaultForEnumShouldBeOneOfTheOptions",
    "TestBlueprintDefaultForRadioShouldBeOneOfTheOptions",
    "TestBlueprintDefaultForCheckboxShouldBeBoolean",
    "TestBlueprintDefaultForStringShouldBeString",
    "TestBlueprintDefaultForColorShouldBeVec4",
    "TestBlueprintDefaultForSliderIntShouldBeInteger",
    "TestBlueprintDefaultForSliderFloatShouldBeNumber",
    "TestBlueprintDefaultForDragIntShouldBeInteger",
    "TestBlueprintDefaultForDragFloatShouldBeNumber",
    "TestBlueprintDefaultForSliderShouldBeBetweenMinAndMax",
    "TestBlueprintDefaultForDragShouldBeBetweenMinAndMax",
    -- -- Options
    "BlueprintShouldHaveOptionsForEnum",
    "BlueprintShouldHaveOptionsForRadio",
    "BlueprintOptionsForEnumShouldHaveAChoicesArrayOfStrings",
    "BlueprintOptionsForRadioShouldHaveAChoicesArrayOfStrings",
    "BlueprintShouldHaveMinAndMaxForSlider",
    "BlueprintMinAndMaxForSliderShouldBeNumbers",
    "BlueprintMinShouldBeLessThanMaxForSlider",
    "TestBlueprintVisibleIfRejectsUnknownSettingId",
    "TestBlueprintVisibleIfAllowsValidCondition",
    "TestBlueprintVisibleIfRejectsEmptyConditionGroup",
    "TestBlueprintVisibleIfRejectsAdditionalGroupFields",
    "TestBlueprintVisibleIfRejectsAdditionalConditionFields",
    "TestBlueprintVisibleIfAllowsNumberExpectedValue",
    "TestBlueprintVisibleIfAllowsRelationalOperatorWithStringExpectedValue",
    "TestBlueprintVisibleIfAllowsRelationalOperatorWithBooleanExpectedValue",
    "TestBlueprintVisibleIfAllowsRelationalOperatorWithNumberExpectedValue",
    "TestBlueprintVisibleIfRejectsDuplicateConditions",
    "TestBlueprintVisibleIfAllowsValidOrConditionGroup",
    "TestBlueprintVisibleIfAllowsValidTabAndSectionConditions",
    "TestKeybindingV2OptionFlagsMustBeBoolean",
    "TestKeybindingV2MouseDefaultButtonBounds",

    --- Broader blueprint integration tests?
})

local function preprocessAndSanitize(rawData, modUUID)
    local preprocessedData = DataPreprocessing:PreprocessData(rawData, modUUID)
    if not preprocessedData then
        return nil, nil
    end

    local blueprint = Blueprint:New(preprocessedData)
    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
    return sanitizedBlueprint, blueprint
end

function TestSanitizeBlueprintWithSchemaVersion()
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

    TestSuite.AssertNotNil(sanitizedBlueprint)
end

function TestSanitizeBlueprintWithoutSchemaVersion()
    local rawData = {}
    local modUUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = preprocessAndSanitize(rawData, modUUID)

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintShouldntHaveSections()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintShouldHaveTabsOrSettings()
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

    TestSuite.AssertNotNil(sanitizedBlueprint1)
    TestSuite.AssertNotNil(sanitizedBlueprint2)
end

function TestRootSettingsBlueprintIsValidThroughUsualPath()
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
    TestSuite.AssertNotNil(sanitizedBlueprint)
    TestSuite.AssertEquals(#blueprint:GetSettings(), 1)
    TestSuite.AssertEquals(blueprint:GetSettings()[1]:GetId(), "CheckboxSetting")
end

function TestBlueprintCanAddRootLevelSettingWithoutTabs()
    local modUUID = TestConstants.ModuleUUIDs[1]
    local rawData = {
        SchemaVersion = 1,
        Settings = {}
    }

    local _sanitizedBlueprint, blueprint = preprocessAndSanitize(rawData, modUUID)
    TestSuite.AssertNotNil(blueprint)

    blueprint:AddSetting({
        Id = "root-setting",
        Name = "Root Setting",
        Type = "checkbox",
        Default = true,
    })

    local rootSettings = blueprint:GetSettings()
    TestSuite.AssertEquals(#rootSettings, 1)
    TestSuite.AssertEquals(rootSettings[1]:GetId(), "root-setting")

    local allSettings = blueprint:GetAllSettings()
    TestSuite.AssertNotNil(allSettings["root-setting"])
    TestSuite.AssertTrue(blueprint:RetrieveDefaultValueForSetting("root-setting") == true)

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
    TestSuite.AssertNotNil(sanitizedBlueprint)
end

function TestBlueprintShouldntHaveTabsAndSettings()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintShouldHaveSettingsAtSomeLevel()
    local allSettingsRootLevel = TestConstants.Blueprints.SettingsRootLevel:GetAllSettings()
    local allSettingsTabLevel = TestConstants.Blueprints.SettingsTabLevel:GetAllSettings()
    local allSettingsSectionLevel = TestConstants.Blueprints.SettingsSectionLevel:GetAllSettings()

    TestSuite.AssertTrue(next(allSettingsRootLevel) ~= nil)
    TestSuite.AssertTrue(next(allSettingsTabLevel) ~= nil)
    TestSuite.AssertTrue(next(allSettingsSectionLevel) ~= nil)
end

function TestUniqueTabIds()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestUniqueSectionIds()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestUniqueSettingIds()
    local blueprintWithRepeatedIDAtRootLevel = TestConstants.Blueprints.SettingsRootLevel
    blueprintWithRepeatedIDAtRootLevel.Settings[1].Id = blueprintWithRepeatedIDAtRootLevel.Settings[2].Id

    local blueprintWithRepeatedIDAtTabLevel = TestConstants.Blueprints.SettingsTabLevel
    blueprintWithRepeatedIDAtTabLevel.Tabs[1].Settings[1].Id = blueprintWithRepeatedIDAtTabLevel.Tabs[1].Settings[2].Id

    local blueprintWithRepeatedIDAtSectionLevel = TestConstants.Blueprints.SettingsSectionLevel
    blueprintWithRepeatedIDAtSectionLevel.Tabs[1].Sections[1].Settings[1].Id = blueprintWithRepeatedIDAtSectionLevel
        .Tabs[1].Sections[1].Settings[2].Id

    local modUUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprintRoot = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithRepeatedIDAtRootLevel, modUUID)
    local sanitizedBlueprintTab = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithRepeatedIDAtTabLevel, modUUID)
    local sanitizedBlueprintSection = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithRepeatedIDAtSectionLevel,
        modUUID)

    TestSuite.AssertNil(sanitizedBlueprintRoot)
    TestSuite.AssertNil(sanitizedBlueprintTab)
    TestSuite.AssertNil(sanitizedBlueprintSection)
end

function TestValidateSettingType()
    local blueprint = TestConstants.Blueprints.SettingsRootLevel
    blueprint.Settings[1].Type = "invalid"
    TestSuite.Not(TestSuite.AssertContains)(TestConstants.validTypes, blueprint.Settings[1].Type)

    local modUUID = TestConstants.ModuleUUIDs[1]
    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
    TestSuite.AssertNil(sanitizedBlueprint)

    ---

    blueprint = TestConstants.Blueprints.SettingsTabLevel
    blueprint.Tabs[1].Settings[1].Type = "invalid"
    TestSuite.Not(TestSuite.AssertContains)(TestConstants.validTypes, blueprint.Tabs[1].Settings[1].Type)

    sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
    TestSuite.AssertNil(sanitizedBlueprint)

    ---

    blueprint = TestConstants.Blueprints.SettingsSectionLevel
    blueprint.Tabs[1].Sections[1].Settings[1].Type = "invalid"
    TestSuite.Not(TestSuite.AssertContains)(TestConstants.validTypes, blueprint.Tabs[1].Sections[1].Settings[1].Type)

    sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
    TestSuite.AssertNil(sanitizedBlueprint)
end

function BlueprintShouldHaveOptionsForEnum()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function BlueprintShouldHaveOptionsForRadio()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function BlueprintOptionsForEnumShouldHaveAChoicesArrayOfStrings()
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

    TestSuite.AssertNil(sanitizedBlueprint)
    TestSuite.AssertNil(sanitizedBlueprintWithChoices)
end

function BlueprintOptionsForRadioShouldHaveAChoicesArrayOfStrings()
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

    TestSuite.AssertNil(sanitizedBlueprint)
    TestSuite.AssertNil(sanitizedBlueprintWithChoices)
    TestSuite.AssertNotNil(sanitizedBlueprintWithStringChoices)
end

function BlueprintShouldHaveMinAndMaxForSlider()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function BlueprintMinAndMaxForSliderShouldBeNumbers()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function BlueprintMinShouldBeLessThanMaxForSlider()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForEnumShouldBeOneOfTheOptions()
    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Settings = {
            {
                SettingId = "setting-1",
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForRadioShouldBeOneOfTheOptions()
    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Settings = {
            {
                SettingId = "setting-1",
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestHasSchemaVersionsEntry()
    local validData = Blueprint:New({
        SchemaVersion = 1
    })

    local invalidData1 = {}

    local invalidData2 = Blueprint:New({
        SchemaVersion = "1"
    })

    TestSuite.AssertTrue(BlueprintPreprocessing:HasSchemaVersionsEntry(validData, TestConstants.ModuleUUIDs[1]))
    TestSuite.AssertFalse(BlueprintPreprocessing:HasSchemaVersionsEntry(invalidData1, TestConstants.ModuleUUIDs[1]))
    TestSuite.AssertFalse(BlueprintPreprocessing:HasSchemaVersionsEntry(invalidData2, TestConstants.ModuleUUIDs[1]))
end

function TestPreprocessData()
    local data = {
        SchemaVersion = 1,
        ModName = "Test Mod",
        KeybindingSortMode = "blueprint",
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
    TestSuite.AssertEquals(preprocessedData.SchemaVersion, 1)
    TestSuite.AssertEquals(preprocessedData.ModName, "Test Mod")
    TestSuite.AssertEquals(preprocessedData.KeybindingSortMode, "blueprint")
    TestSuite.AssertEquals(#preprocessedData.Tabs, 1)

    local tab = preprocessedData.Tabs[1]
    TestSuite.AssertEquals(tab.TabId, "tab-1")
    TestSuite.AssertEquals(tab.TabName, "Tab 1")
    TestSuite.AssertEquals(#tab.Settings, 1)
    TestSuite.AssertEquals(#tab.Sections, 1)

    local setting1 = tab.Settings[1]
    TestSuite.AssertEquals(setting1.Id, "setting-1")
    TestSuite.AssertEquals(setting1.Name, "Setting 1")
    TestSuite.AssertEquals(setting1.Type, "boolean")
    TestSuite.AssertEquals(setting1.Default, true)
    TestSuite.AssertEquals(setting1.Description, "Description 1")
    TestSuite.AssertEquals(setting1.Tooltip, "Tooltip 1")

    local section1 = tab.Sections[1]
    TestSuite.AssertEquals(section1.SectionId, "section-1")
    TestSuite.AssertEquals(section1.SectionName, "Section 1")
    TestSuite.AssertEquals(#section1.Settings, 1)

    local setting2 = section1.Settings[1]
    TestSuite.AssertEquals(setting2.Id, "setting-2")
    TestSuite.AssertEquals(setting2.Name, "Setting 2")
    TestSuite.AssertEquals(setting2.Type, "number")
    TestSuite.AssertEquals(setting2.Default, 42)
    TestSuite.AssertEquals(setting2.Description, "Description 2")
    TestSuite.AssertEquals(setting2.Tooltip, "Tooltip 2")
end

function TestBlueprintDefaultForIntShouldBeNumber()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForFloatShouldBeNumber()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForEnumShouldBeOneOfTheOptions()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForRadioShouldBeOneOfTheOptions()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForCheckboxShouldBeBoolean()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForStringShouldBeString()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForColorShouldBeVec4()
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

    TestSuite.AssertNil(sanitizedBlueprint)
    TestSuite.AssertNotNil(sanitizedCorrectBlueprint)
end

function TestBlueprintDefaultForSliderIntShouldBeInteger()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForSliderFloatShouldBeNumber()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForDragIntShouldBeInteger()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForDragFloatShouldBeNumber()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForSliderShouldBeBetweenMinAndMax()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForDragShouldBeBetweenMinAndMax()
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

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TabsCanHaveEitherTabIdOrId()
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

    TestSuite.AssertNotNil(validTab1)
    TestSuite.AssertNotNil(validTab2)
    TestSuite.AssertEquals(blueprintWithIdAlias:GetTabs()[1]:GetId(), "tab-2")
    TestSuite.AssertNil(invalidTab)
end

function TabsCanHaveEitherTabNameOrName()
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

    TestSuite.AssertNotNil(validTab1)
    TestSuite.AssertNotNil(validTab2)
    TestSuite.AssertEquals(blueprintWithNameAlias:GetTabs()[1]:GetTabName(), "Tab 2")
    TestSuite.AssertNil(invalidTab)
end

function SectionsCanHaveEitherSectionIdOrId()
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

    local validSection1 = DataPreprocessing:RecursivePreprocess(validSectionData1, TestConstants.ModuleUUIDs[1])
    local validSection2 = DataPreprocessing:RecursivePreprocess(validSectionData2, TestConstants.ModuleUUIDs[1])
    local invalidSection = DataPreprocessing:RecursivePreprocess(invalidSectionData, TestConstants.ModuleUUIDs[1])

    TestSuite.AssertNotNil(validSection1)
    TestSuite.AssertNotNil(validSection2)
    TestSuite.AssertNil(invalidSection)
end

function SectionsCanHaveEitherSectionNameOrName()
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

    local validSection1 = DataPreprocessing:RecursivePreprocess(validSectionData1, TestConstants.ModuleUUIDs[1])
    local validSection2 = DataPreprocessing:RecursivePreprocess(validSectionData2, TestConstants.ModuleUUIDs[1])
    local invalidSection = DataPreprocessing:RecursivePreprocess(invalidSectionData, TestConstants.ModuleUUIDs[1])

    TestSuite.AssertNotNil(validSection1)
    TestSuite.AssertNotNil(validSection2)
    TestSuite.AssertNil(invalidSection)
end

function TestBlueprintVisibleIfRejectsUnknownSettingId()
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
    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintVisibleIfAllowsValidCondition()
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
    TestSuite.AssertNotNil(sanitizedBlueprint)
end

function TestBlueprintVisibleIfRejectsEmptyConditionGroup()
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
    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintVisibleIfRejectsAdditionalGroupFields()
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
    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintVisibleIfRejectsAdditionalConditionFields()
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
    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintVisibleIfAllowsNumberExpectedValue()
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
    TestSuite.AssertNotNil(sanitizedBlueprint)
end

function TestBlueprintVisibleIfAllowsRelationalOperatorWithStringExpectedValue()
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
    TestSuite.AssertNotNil(sanitizedBlueprint)
end

function TestBlueprintVisibleIfAllowsRelationalOperatorWithBooleanExpectedValue()
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
    TestSuite.AssertNotNil(sanitizedBlueprint)
end

function TestBlueprintVisibleIfAllowsRelationalOperatorWithNumberExpectedValue()
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
    TestSuite.AssertNotNil(sanitizedBlueprint)
end

function TestBlueprintVisibleIfRejectsDuplicateConditions()
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
    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintVisibleIfAllowsValidOrConditionGroup()
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
    TestSuite.AssertNotNil(sanitizedBlueprint)
end

function TestBlueprintVisibleIfAllowsValidTabAndSectionConditions()
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
    TestSuite.AssertNotNil(sanitizedBlueprint)
end

function TestKeybindingV2OptionFlagsMustBeBoolean()
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

    TestSuite.AssertNil(invalidResult)
    TestSuite.AssertNotNil(validResult)
end

function TestKeybindingV2MouseDefaultButtonBounds()
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

    TestSuite.AssertNotNil(validResult)
    TestSuite.AssertNil(invalidResult)
end
