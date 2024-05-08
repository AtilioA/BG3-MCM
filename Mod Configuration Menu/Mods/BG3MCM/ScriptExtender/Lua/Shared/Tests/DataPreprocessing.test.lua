-- (FROM OLD MARKDOWN NOTES) The blueprint will be validated in the following ways:

-- - Check if each setting has a `Name`, `Type`, `Default`, and `Description` key;
-- - Check if the `Type` key is one of the supported types (`int`, `float`, `checkbox`, `text`, `enum`, `slider`, `radio`);
-- - Check if the `Default` key is of the correct type according to the `Type` key;
-- - Check if the `Options` key is present for `enum`, `radio`types;
-- - Check if the `Options` key is an array of strings for `enum` and `radio` types;
-- - Check if the `Min` and `Max` keys are present for `slider` type;
-- - Check if the `Min` and `Max` keys are numbers for `slider` type;
-- - Check if the `Min` key is less than the `Max` key for `slider`, `drag` types;
-- - Check if ID is unique for each setting across the blueprint.

TestSuite.RegisterTests("DataPreprocessing", {
    -- Blueprint structure validation
    "TestSanitizeBlueprintWithSchemaVersion",
    "TestSanitizeBlueprintWithoutSchemaVersion",
    "TestBlueprintShouldntHaveSections",
    "TestBlueprintShouldntHaveTabsAndSettings",
    "TestBlueprintShouldHaveSettingsAtSomeLevel",

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
    -- "TestBlueprintDefaultForDragShouldBeBetweenMinAndMax",
    -- -- Options
    "BlueprintShouldHaveOptionsForEnum",
    "BlueprintShouldHaveOptionsForRadio",
    "BlueprintOptionsForEnumShouldHaveAChoicesArrayOfStrings",
    "BlueprintOptionsForRadioShouldHaveAChoicesArrayOfStrings",
    "BlueprintShouldHaveMinAndMaxForSlider",
    "BlueprintMinAndMaxForSliderShouldBeNumbers",
    "BlueprintMinShouldBeLessThanMaxForSlider",

    --- Broader blueprint integration tests?
    -- "TestSanitizeBlueprints",
    -- "TestValidateSettings",
    -- "TestHasSchemaVersionsEntry",
    -- "TestPreprocessData"
})

function TestSanitizeBlueprintWithSchemaVersion()
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
                TabId = "tab-3",
            },
        }
    })
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNotNil(sanitizedBlueprint)
end

function TestSanitizeBlueprintWithoutSchemaVersion()
    local blueprint = Blueprint:New({
    })
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintShouldntHaveSections()
    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Settings = {}
    })
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintShouldHaveTabsOrSettings()
    local blueprintWithTabs = Blueprint:New({
        SchemaVersion = 1,
        Tabs = {
            {
                TabId = "tab-1",
            },
            {
                TabId = "tab-2",
            },
            {
                TabId = "tab-3",
            },
        },
    })
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint1 = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithTabs, modGUID)

    local blueprintWithSettings = Blueprint:New({
        SchemaVersion = 1,
        Settings = {
            {
                Id = "setting-1",
            },
            {
                Id = "setting-2",
            },
            {
                Id = "setting-3",
            },

        }
    })

    local modGUID2 = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint2 = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithSettings, modGUID2)


    TestSuite.AssertTrue(sanitizedBlueprint1 ~= nil and sanitizedBlueprint2 ~= nil)
end

function TestBlueprintShouldntHaveTabsAndSettings()
    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Tabs = {
            TabId = "tab-1",
        },
        Settings = {
            SettingId = "setting-1",
        }
    })
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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

    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprintRoot = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithRepeatedIDAtRootLevel, modGUID)
    local sanitizedBlueprintTab = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithRepeatedIDAtTabLevel, modGUID)
    local sanitizedBlueprintSection = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithRepeatedIDAtSectionLevel,
        modGUID)

    TestSuite.AssertNil(sanitizedBlueprintRoot)
    TestSuite.AssertNil(sanitizedBlueprintTab)
    TestSuite.AssertNil(sanitizedBlueprintSection)
end

function TestValidateSettingType()
    local blueprint = TestConstants.Blueprints.SettingsRootLevel
    blueprint.Settings[1].Type = "invalid"
    TestSuite.Not(TestSuite.AssertContains)(TestConstants.validTypes, blueprint.Settings[1].Type)

    local modGUID = TestConstants.ModuleUUIDs[1]
    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)
    TestSuite.AssertNil(sanitizedBlueprint)

    ---

    blueprint = TestConstants.Blueprints.SettingsTabLevel
    blueprint.Tabs[1].Settings[1].Type = "invalid"
    TestSuite.Not(TestSuite.AssertContains)(TestConstants.validTypes, blueprint.Tabs[1].Settings[1].Type)

    sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)
    TestSuite.AssertNil(sanitizedBlueprint)

    ---

    blueprint = TestConstants.Blueprints.SettingsSectionLevel
    blueprint.Tabs[1].Sections[1].Settings[1].Type = "invalid"
    TestSuite.Not(TestSuite.AssertContains)(TestConstants.validTypes, blueprint.Tabs[1].Sections[1].Settings[1].Type)

    sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)
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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)
    local sanitizedBlueprintWithChoices = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithChoices, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)
    local sanitizedBlueprintWithChoices = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithChoices, modGUID)
    local sanitizedBlueprintWithStringChoices = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithStringChoices,
        modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestSanitizeBlueprints()
    local mods = {
        [TestConstants.ModuleUUIDs[1]] = {
            blueprint = {
                SchemaVersion = 1,
                someValue = "true"
            }
        },
        [TestConstants.ModuleUUIDs[2]] = {
            blueprint = {
                SchemaVersion = 1,
                anotherValue = "false"
            }
        },
        [TestConstants.ModuleUUIDs[3]] = {
            blueprint = {
                someValue = "true"
            }
        }
    }

    BlueprintPreprocessing:SanitizeBlueprints(mods)

    TestSuite.AssertEquals(mods[TestConstants.ModuleUUIDs[1]].blueprint.someValue, true)
    TestSuite.AssertEquals(mods[TestConstants.ModuleUUIDs[2]].blueprint.anotherValue, false)
    TestSuite.AssertNil(mods[TestConstants.ModuleUUIDs[3]])
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
    local data = Blueprint:New({
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
    })

    local preprocessedData = DataPreprocessing:PreprocessData(data, ModuleUUID)

    if preprocessedData == nil then
        error("Preprocessed data is nil")
    end
    TestSuite.AssertEquals(preprocessedData.SchemaVersion, 1)
    TestSuite.AssertEquals(preprocessedData.ModName, "Test Mod")
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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

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

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)
    local sanitizedCorrectBlueprint = BlueprintPreprocessing:SanitizeBlueprint(correctBlueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

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
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNil(sanitizedBlueprint)
end
