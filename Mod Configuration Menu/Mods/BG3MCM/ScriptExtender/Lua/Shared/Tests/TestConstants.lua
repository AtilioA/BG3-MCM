TestConstants = {}

TestConstants.ModuleUUIDs = {
    "f97b43be-7398-4ea5-8fe2-be7eb3d4b5ca", -- Volition Cabinet
    "5b5ad5b6-ce37-4a63-8dea-a1fee4cee156", -- EasyCheat
    "310ba0c7-374e-4e56-8c42-b7c7ad3a38b0", -- Fix Stragglers
    "1c132ec4-4cd2-4c40-aeb9-ff6ee0467da8", -- Auto Send Food To Camp
    "c72d9f6a-a6e4-48b1-98c0-0ecdc7c31cf7", -- Mark Books as Read
}

TestConstants.Blueprints = {
    SettingsRootLevel =
        Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                BlueprintSetting:New({
                    Id = "setting-checkbox",
                    Type = "checkbox",
                    Default = true
                }),
                BlueprintSetting:New({
                    Id = "setting-int",
                    Type = "int",
                    Default = 42
                }),
                BlueprintSetting:New({
                    Id = "setting-slider",
                    Type = "slider",
                    Default = 50,
                    Options = {
                        Min = 0,
                        Max = 100,
                    }
                }),
                BlueprintSetting:New({
                    Id = "setting-enum",
                    Type = "enum",
                    Default = "option-1",
                    Options = {
                        Choices = {
                            "option-1",
                            "option-2",
                            "option-3",
                        }
                    }
                }),
            }
        }),
    SettingsTabLevel =
        Blueprint:New({
            SchemaVersion = 1,
            Tabs = {
                BlueprintTab:New({
                    TabId = "tab-1",
                    TabName = "Tab 1",
                    Settings = {
                        BlueprintSetting:New({
                            Id = "setting-checkbox",
                            Type = "checkbox",
                            Default = true
                        }),
                        BlueprintSetting:New({
                            Id = "setting-int",
                            Type = "int",
                            Default = 42
                        }),
                        BlueprintSetting:New({
                            Id = "setting-slider",
                            Type = "slider",
                            Default = 50,
                            Options = {
                                Min = 0,
                                Max = 100,
                            }
                        }),
                        BlueprintSetting:New({
                            Id = "setting-enum",
                            Type = "enum",
                            Default = "option-1",
                            Options = {
                                Choices = {
                                    "option-1",
                                    "option-2",
                                    "option-3",
                                }
                            }
                        }),
                    }
                })
            }
        }),

    SettingsSectionLevel =
        Blueprint:New({
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
                                    Id = "setting-checkbox",
                                    Type = "checkbox",
                                    Default = true
                                }),
                                BlueprintSetting:New({
                                    Id = "setting-int",
                                    Type = "int",
                                    Default = 42
                                }),
                                BlueprintSetting:New({
                                    Id = "setting-slider",
                                    Type = "slider",
                                    Default = 50,
                                    Options = {
                                        Min = 0,
                                        Max = 100,
                                    }
                                }),
                                BlueprintSetting:New({
                                    Id = "setting-enum",
                                    Type = "enum",
                                    Default = "option-1",
                                    Options = {
                                        Choices = {
                                            "option-1",
                                            "option-2",
                                            "option-3",
                                        }
                                    }
                                }),
                            }
                        })
                    }
                })
            },
        }),
}

TestConstants.validTypes = {
    "checkbox",
    "int",
    "float",
    "slider_int",
    "slider_float",
    "drag_int",
    "drag_float",
    "enum",
    "string",
    "color_picker",
    "color_edit"
}

return TestConstants
