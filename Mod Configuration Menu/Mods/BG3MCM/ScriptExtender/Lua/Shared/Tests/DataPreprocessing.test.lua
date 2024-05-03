TestSuite.RegisterTests("DataPreprocessing", {
    -- Blueprint structure validation
    "TestSanitizeBlueprintWithSchemaVersion",
    "TestSanitizeBlueprintWithoutSchemaVersion",
    "TestBlueprintShouldntHaveSections",
    "TestBlueprintShouldntHaveTabsAndSettings",
    "TestBlueprintShouldHaveTabsOrSettings",

    -- Blueprint integrity validation
    "TestUniqueTabIds",
    "TestUniqueSectionIds",
    "TestUniqueSettingIds",

    -- Blueprint (setting definition) validation
    "TestBlueprintDefaultForEnumShouldBeOneOfTheOptions",
    "TestBlueprintDefaultForRadioShouldBeOneOfTheOptions",
    "TestBlueprintDefaultForCheckboxShouldBeBoolean",
    -- "TestBlueprintDefaultForNumberShouldBeNumber",
    -- "TestBlueprintDefaultForStringShouldBeString",
    -- "TestBlueprintDefaultForColorShouldBeString",
    -- "TestBlueprintDefaultForSliderShouldBeNumber",

    -- Overall blueprint/function validation
    -- "TestSanitizeBlueprints",
    -- "TestValidateSettings",
    -- "TestValidateAndFixSettings",
    -- "TestHasSchemaVersionsEntry",
    -- "TestHasSectionsEntry",
    -- "TestPreprocessData"
})

function TestSanitizeBlueprintWithSchemaVersion()
    local blueprint = {
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
    }
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = DataPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNotNil(sanitizedBlueprint)
end

function TestSanitizeBlueprintWithoutSchemaVersion()
    local blueprint = {
    }
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = DataPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintShouldntHaveSections()
    local blueprint = {
        SchemaVersion = 1,
        Settings = {}
    }
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = DataPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintShouldHaveTabsOrSettings()
    local blueprintWithTabs = {
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
    }
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint1 = DataPreprocessing:SanitizeBlueprint(blueprintWithTabs, modGUID)

    local blueprintWithSettings = {
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
    }

    local modGUID2 = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint2 = DataPreprocessing:SanitizeBlueprint(blueprintWithSettings, modGUID2)


    TestSuite.AssertTrue(sanitizedBlueprint1 ~= nil and sanitizedBlueprint2 ~= nil)
end

function TestBlueprintShouldntHaveTabsAndSettings()
    local blueprint = {
        SchemaVersion = 1,
        Tabs = {
            TabId = "tab-1",
        },
        Settings = {
            SettingId = "setting-1",
        }
    }
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = DataPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestUniqueTabIds()
    local blueprint = {
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
    }
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = DataPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestUniqueSectionIds()
    local blueprint = {
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
    }
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = DataPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestUniqueSettingIds()
    -- local blueprint = {
    --     SchemaVersion = 1,
    --     Tabs = {
    --         {
    --             TabId = "tab-1",
    --             Sections = {
    --                 {
    --                     SectionId = "section-1",
    --                     Settings = {
    --                         {
    --                             SettingId = "setting-1",
    --                         },
    --                         {
    --                             SettingId = "setting-2",
    --                         },
    --                         {
    --                             SettingId = "setting-1",
    --                         },
    --                     }
    --                 }
    --             }
    --         }
    --     }
    -- }
    local blueprint = {
        SchemaVersion = 1,
        Settings = {
            {
                Id = "setting-1",
            },
            {
                Id = "setting-2",
            },
            {
                Id = "setting-1",
            },
        }
    }
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = DataPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForEnumShouldBeOneOfTheOptions()
    local blueprint = {
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
    }
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = DataPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNil(sanitizedBlueprint)
end

function TestBlueprintDefaultForRadioShouldBeOneOfTheOptions()
    local blueprint = {
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
    }
    local modGUID = TestConstants.ModuleUUIDs[1]

    local sanitizedBlueprint = DataPreprocessing:SanitizeBlueprint(blueprint, modGUID)

    TestSuite.AssertNil(sanitizedBlueprint)
end

