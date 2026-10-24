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
        D.expect(sanitizedBlueprint:GetAllSettings()["setting-1"]:GetType()).toBe("checkbox")
        D.expect(sanitizedBlueprint:RetrieveDefaultValueForSetting("setting-1")).toBe(true)
    end)

    D.test("TestSanitizeBlueprintWithoutSchemaVersion", function()
        local rawData = {}
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = preprocessAndSanitize(rawData, modUUID)
        local sanitizedWithVersion = preprocessAndSanitize({ SchemaVersion = 1 }, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
        D.expect(sanitizedWithVersion).Not.toBeNil()
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
        D.expect(sanitizedBlueprint:RetrieveDefaultValueForSetting("setting-1")).toBe(true)
        local section = sanitizedBlueprint:GetSections()[1]
        D.expect(section:GetId()).toBe("section-1")
        D.expect(section:GetLocaName()).toBe("Section 1")
        D.expect(#section:GetSettings()).toBe(1)
        D.expect(section:GetSettings()[1]:GetId()).toBe("setting-1")
    end)

    D.test("TestBlueprintAllowsNoSettings", function()
        local rawData = {
            SchemaVersion = 1,
        }
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = preprocessAndSanitize(rawData, modUUID)

        D.expect(sanitizedBlueprint).Not.toBeNil()
        D.expect(BlueprintShape:HasAnySettings(sanitizedBlueprint)).toBe(false)
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
        D.expect(sanitizedBlueprint1:GetTabs()[1]:GetId()).toBe("tab-1")
        D.expect(sanitizedBlueprint2:GetSettings()[1]:GetId()).toBe("setting-1")
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
        D.expect(blueprint:RetrieveDefaultValueForSetting("root-setting")).toBe(true)

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
        local rawDataTabsOnly = {
            SchemaVersion = 1,
            Tabs = rawData.Tabs,
        }
        local modUUID = TestConstants.ModuleUUIDs[1]

        D.expect(preprocessAndSanitize(rawDataTabsOnly, modUUID)).Not.toBeNil()
        D.expect(preprocessAndSanitize(rawData, modUUID)).toBeNil()
    end)

    D.test("TestBlueprintShouldHaveSettingsAtSomeLevel", function()
        local modUUID = TestConstants.ModuleUUIDs[1]

        local rootLevel = preprocessAndSanitize({
            SchemaVersion = 1,
            Settings = {
                { Id = "root-int", Type = "int", Default = 7 },
            },
        }, modUUID)

        local tabLevel = preprocessAndSanitize({
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                    TabName = "Tab 1",
                    Settings = {
                        { Id = "tab-int", Type = "int", Default = 8 },
                    },
                },
            },
        }, modUUID)

        local sectionLevel = preprocessAndSanitize({
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                    TabName = "Tab 1",
                    Sections = {
                        {
                            SectionId = "section-1",
                            SectionName = "Section 1",
                            Settings = {
                                { Id = "section-int", Type = "int", Default = 9 },
                            },
                        },
                    },
                },
            },
        }, modUUID)

        D.expect(rootLevel:RetrieveDefaultValueForSetting("root-int")).toBe(7)
        D.expect(tabLevel:RetrieveDefaultValueForSetting("tab-int")).toBe(8)
        D.expect(sectionLevel:RetrieveDefaultValueForSetting("section-int")).toBe(9)
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

        local topLevelTab = blueprint:GetTabs()[1]
        D.expect(topLevelTab:GetId()).toBe("tab-1")
        D.expect(#topLevelTab:GetTabs()).toBe(1)

        local nestedTab = topLevelTab:GetTabs()[1]
        D.expect(nestedTab:GetId()).toBe("nested-tab-1")
        D.expect(#nestedTab:GetSettings()).toBe(1)
        D.expect(nestedTab:GetSettings()[1]:GetId()).toBe("nested-setting")
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
        local uniqueBlueprint = Blueprint:New({
            SchemaVersion = 1,
            Tabs = {
                { TabId = "tab-1", TabName = "Tab 1" },
                { TabId = "tab-2", TabName = "Tab 2" },
            }
        })
        local duplicateBlueprint = Blueprint:New({
            SchemaVersion = 1,
            Tabs = {
                { TabId = "tab-1", TabName = "Tab 1" },
                { TabId = "tab-2", TabName = "Tab 2" },
                { TabId = "tab-1", TabName = "Tab 3" },
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        D.expect(BlueprintPreprocessing:SanitizeBlueprint(uniqueBlueprint, modUUID)).Not.toBeNil()
        D.expect(BlueprintPreprocessing:SanitizeBlueprint(duplicateBlueprint, modUUID)).toBeNil()
    end)

    D.test("TestUniqueSectionIds", function()
        local uniqueBlueprint = Blueprint:New({
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                    TabName = "Tab 1",
                    Sections = {
                        { SectionId = "section-1", SectionName = "Section 1" },
                        { SectionId = "section-2", SectionName = "Section 2" },
                    },
                }
            }
        })
        local duplicateBlueprint = Blueprint:New({
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                    TabName = "Tab 1",
                    Sections = {
                        { SectionId = "section-1", SectionName = "Section 1" },
                        { SectionId = "section-2", SectionName = "Section 2" },
                        { SectionId = "section-1", SectionName = "Section 3" },
                    },
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        D.expect(BlueprintPreprocessing:SanitizeBlueprint(uniqueBlueprint, modUUID)).Not.toBeNil()
        D.expect(BlueprintPreprocessing:SanitizeBlueprint(duplicateBlueprint, modUUID)).toBeNil()
    end)

    D.test("TestUniqueSettingIds", function()
        local uniqueRootLevel = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                { Id = "setting-a", Type = "checkbox", Default = true },
                { Id = "setting-b", Type = "checkbox", Default = false },
            }
        })
        local duplicateRootLevel = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                { Id = "setting-a", Type = "checkbox", Default = true },
                { Id = "setting-a", Type = "checkbox", Default = false },
            }
        })
        local duplicateTabLevel = Blueprint:New({
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                    TabName = "Tab 1",
                    Settings = {
                        { Id = "setting-a", Type = "checkbox", Default = true },
                        { Id = "setting-a", Type = "checkbox", Default = false },
                    },
                }
            }
        })
        local duplicateSectionLevel = Blueprint:New({
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "tab-1",
                    TabName = "Tab 1",
                    Sections = {
                        {
                            SectionId = "section-1",
                            SectionName = "Section 1",
                            Settings = {
                                { Id = "setting-a", Type = "checkbox", Default = true },
                                { Id = "setting-a", Type = "checkbox", Default = false },
                            },
                        }
                    }
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        D.expect(BlueprintPreprocessing:SanitizeBlueprint(uniqueRootLevel, modUUID)).Not.toBeNil()
        D.expect(BlueprintPreprocessing:SanitizeBlueprint(duplicateRootLevel, modUUID)).toBeNil()
        D.expect(BlueprintPreprocessing:SanitizeBlueprint(duplicateTabLevel, modUUID)).toBeNil()
        D.expect(BlueprintPreprocessing:SanitizeBlueprint(duplicateSectionLevel, modUUID)).toBeNil()
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
        local validBlueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-float",
                    Type = "float",
                    Default = 1.5
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        D.expect(BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)).toBeNil()
        D.expect(BlueprintPreprocessing:SanitizeBlueprint(validBlueprint, modUUID)).Not.toBeNil()
    end)

    D.test("TestBlueprintDefaultForEnumShouldBeOneOfTheOptions", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-enum",
                    Type = "enum",
                    Options = {
                        Choices = { "option-1", "option-2", "option-3" }
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
                        Choices = { "option-1", "option-2", "option-3" }
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
        D.expect(sanitizedBlueprint:RetrieveDefaultValueForSetting("setting-enum")).toBe("runtime-value")
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
        D.expect(sanitizedBlueprint:RetrieveDefaultValueForSetting("setting-enum")).toBe("Runtime Only")
    end)

    D.test("BlueprintShouldHaveOptionsForRadio", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-radio",
                    Type = "radio",
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
                        Choices = { "option-1", "option-2" }
                    },
                    Default = "option-1"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        D.expect(BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)).toBeNil()
        D.expect(BlueprintPreprocessing:SanitizeBlueprint(blueprintWithChoices, modUUID)).Not.toBeNil()
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
        local blueprintWithInvalidChoiceType = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-enum",
                    Type = "enum",
                    Options = {
                        Choices = { "option-1", 2 }
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
                            "option-1", "option-2"
                        }
                    },
                    Default = "option-1"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
        local sanitizedBlueprintWithInvalidChoiceType = BlueprintPreprocessing:SanitizeBlueprint(
            blueprintWithInvalidChoiceType, modUUID)
        local sanitizedBlueprintWithChoices = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithChoices, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
        D.expect(sanitizedBlueprintWithInvalidChoiceType).toBeNil()
        D.expect(sanitizedBlueprintWithChoices).Not.toBeNil()
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
        local blueprintWithInvalidChoiceType = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-radio",
                    Type = "radio",
                    Options = {
                        Choices = { "option-1", 2 }
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
                            "option-1", "option-2"
                        }
                    },
                    Default = "option-1"
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        local sanitizedBlueprint = BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
        local sanitizedBlueprintWithInvalidChoiceType = BlueprintPreprocessing:SanitizeBlueprint(
            blueprintWithInvalidChoiceType, modUUID)
        local sanitizedBlueprintWithChoices = BlueprintPreprocessing:SanitizeBlueprint(blueprintWithChoices, modUUID)

        D.expect(sanitizedBlueprint).toBeNil()
        D.expect(sanitizedBlueprintWithInvalidChoiceType).toBeNil()
        D.expect(sanitizedBlueprintWithChoices).Not.toBeNil()
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
        local validBlueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting-slider",
                    Type = "slider_int",
                    Default = 50,
                    Options = {
                        Min = 0,
                        Max = 100,
                    }
                }
            }
        })
        local modUUID = TestConstants.ModuleUUIDs[1]

        D.expect(BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)).toBeNil()
        D.expect(BlueprintPreprocessing:SanitizeBlueprint(validBlueprint, modUUID)).Not.toBeNil()
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
                        Min = 50,
                        Max = 50
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

        local blueprintWithKnownSettingId = Blueprint:New({
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
                        }
                    }
                }
            }
        })

        D.expect(BlueprintPreprocessing:SanitizeBlueprint(blueprintWithKnownSettingId, TestConstants.ModuleUUIDs[1]))
            .Not.toBeNil()
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
        D.expect(sanitizedBlueprint:GetSettingById("dependent-setting"):GetVisibleIf().LogicalOperator).toBe("and")
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
        D.expect(sanitizedBlueprint:GetSettingById("dependent-setting"):GetVisibleIf().Conditions[1].ExpectedValue).toBe(1)
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
        D.expect(sanitizedBlueprint:GetSettingById("dependent-setting"):GetVisibleIf().Conditions[1].ExpectedValue).toBe("1")
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
        D.expect(sanitizedBlueprint:GetSettingById("dependent-setting"):GetVisibleIf().Conditions[1].ExpectedValue).toBe(true)
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
        D.expect(sanitizedBlueprint:GetSettingById("dependent-setting"):GetVisibleIf().Conditions[1].Operator).toBe(">=")
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

        local visibleIf = sanitizedBlueprint:GetSettingById("dependent-setting"):GetVisibleIf()
        D.expect(visibleIf.LogicalOperator).toBe("or")
        D.expect(#visibleIf.Conditions).toBe(2)
        D.expect(visibleIf.Conditions[1].SettingId).toBe("master-toggle")
        D.expect(visibleIf.Conditions[1].Operator).toBe("==")
        D.expect(visibleIf.Conditions[1].ExpectedValue).toBe(true)
        D.expect(visibleIf.Conditions[2].SettingId).toBe("mode")
        D.expect(visibleIf.Conditions[2].Operator).toBe("==")
        D.expect(visibleIf.Conditions[2].ExpectedValue).toBe("expert")
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

        local tab = sanitizedBlueprint:GetTabs()[1]
        local section = tab:GetSections()[1]
        D.expect(tab:GetVisibleIf().Conditions[1].SettingId).toBe("master-toggle")
        D.expect(tab:GetVisibleIf().Conditions[1].Operator).toBe("==")
        D.expect(tab:GetVisibleIf().Conditions[1].ExpectedValue).toBe(true)
        D.expect(section:GetVisibleIf().Conditions[1].SettingId).toBe("master-toggle")
        D.expect(section:GetVisibleIf().Conditions[1].Operator).toBe("==")
        D.expect(section:GetVisibleIf().Conditions[1].ExpectedValue).toBe(true)
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
                        AllowConflict = true,
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

    D.test("TestKeybindingV2KeyboardDefaultModifiersCanonicalizeToEmptyList", function()
        local rawData = {
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "kb-empty-keyboard-modifier",
                    Type = "keybinding_v2",
                    Default = {
                        Keyboard = {
                            Key = "A",
                            ModifierKeys = { "", "NONE", "none" },
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
        D.expect(keyboardDefault.ModifierKeys).toEqual({})
    end)

    D.test("TestKeybindingV2MouseDefaultModifiersCanonicalizeToEmptyList", function()
        local rawData = {
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "kb-empty-mouse-modifier",
                    Type = "keybinding_v2",
                    Default = {
                        Mouse = {
                            Button = 1,
                            ModifierKeys = { "", "NONE", "none" },
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
        D.expect(mouseDefault.ModifierKeys).toEqual({})
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

        D.expect(BlueprintPreprocessing:HasSchemaVersionsEntry(validData, TestConstants.ModuleUUIDs[1])).toBe(true)
        D.expect(BlueprintPreprocessing:HasSchemaVersionsEntry(invalidData1, TestConstants.ModuleUUIDs[1])).toBe(false)
        D.expect(BlueprintPreprocessing:HasSchemaVersionsEntry(invalidData2, TestConstants.ModuleUUIDs[1])).toBe(false)
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
        D.expect(#preprocessedData.Tabs).toBe(1)

        local alphabeticalData = DataPreprocessing:PreprocessData({
            SchemaVersion = 1,
            KeybindingSortMode = KeybindingSortMode.ALPHABETICAL,
        }, ModuleUUID)
        D.expect(alphabeticalData.KeybindingSortMode).toBe("alphabetical")

        local tab = preprocessedData.Tabs[1]
        D.expect(tab:GetId()).toBe("tab-1")
        D.expect(tab:GetTabName()).toBe("Tab 1")
        D.expect(#tab:GetSettings()).toBe(1)
        D.expect(#tab:GetSections()).toBe(1)

        local setting1 = tab:GetSettings()[1]
        D.expect(setting1:GetId()).toBe("setting-1")
        D.expect(setting1:GetName()).toBe("Setting 1")
        D.expect(setting1:GetType()).toBe("boolean")
        D.expect(setting1:GetDefault()).toBe(true)
        D.expect(setting1:GetDescription()).toBe("Description 1")
        D.expect(setting1:GetTooltip()).toBe("Tooltip 1")

        local section1 = tab:GetSections()[1]
        D.expect(section1:GetId()).toBe("section-1")
        D.expect(section1:GetLocaName()).toBe("Section 1")
        D.expect(#section1:GetSettings()).toBe(1)

        local setting2 = section1:GetSettings()[1]
        D.expect(setting2:GetId()).toBe("setting-2")
        D.expect(setting2:GetName()).toBe("Setting 2")
        D.expect(setting2:GetType()).toBe("number")
        D.expect(setting2:GetDefault()).toBe(42)
        D.expect(setting2:GetDescription()).toBe("Description 2")
        D.expect(setting2:GetTooltip()).toBe("Tooltip 2")
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
        D.expect(blueprint:GetKeybindingSortMode()).toBe("blueprint")
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

        D.expect(validSection1:GetId()).toBe("section-1")
        D.expect(validSection2:GetId()).toBe("section-2")
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

        D.expect(validSection1:GetLocaName()).toBe("Section 1")
        D.expect(validSection2:GetLocaName()).toBe("Section 2")
        D.expect(invalidSection).toBeNil()
    end)

    D.test("SectionIdAndNameAliasesSurviveTheBlueprintPipeline", function()
        local rawData = {
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "alias-tab",
                    TabName = "Alias Tab",
                    Sections = {
                        {
                            Id = "alias-section",
                            Name = "Alias Section",
                            Settings = {
                                {
                                    Id = "alias-setting",
                                    Type = "checkbox",
                                    Default = true,
                                },
                            },
                        },
                    },
                },
            },
        }

        local sanitizedBlueprint = preprocessAndSanitize(rawData, TestConstants.ModuleUUIDs[1])

        D.expect(sanitizedBlueprint).Not.toBeNil()
        local section = sanitizedBlueprint:GetTabs()[1]:GetSections()[1]
        D.expect(section:GetId()).toBe("alias-section")
        D.expect(section:GetLocaName()).toBe("Alias Section")
        D.expect(#section:GetSettings()).toBe(1)
        D.expect(section:GetSettings()[1]:GetId()).toBe("alias-setting")
        D.expect(sanitizedBlueprint:RetrieveDefaultValueForSetting("alias-setting")).toBe(true)
    end)
end)
