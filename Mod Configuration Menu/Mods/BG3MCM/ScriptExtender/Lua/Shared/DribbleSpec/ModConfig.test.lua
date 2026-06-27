D.describe("ModConfig", { tags = { "modconfig", "unit" } }, function()
    D.test("TestAddKeysMissingFromBlueprintShouldUseOldIdOnlyIfNoValueOnCurrentId", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting2",
                    OldId = "setting1",
                    Type = "string",
                    Default = "def"
                }
            }
        })
        local oldValue = "toto"
        local settings = {
            setting1 = oldValue,
        }

        ModConfig:AddKeysMissingFromBlueprint(blueprint, settings)

        D.expect(settings["setting2"]).toBe(oldValue)
        D.expect(settings["setting1"]).toBe(oldValue)
    end)

    D.test("TestAddKeysMissingFromBlueprintShouldUseNotOldIdOnlyIfValueOnCurrentId", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "setting2",
                    OldId = "setting1",
                    Type = "string",
                    Default = "def"
                }
            }
        })
        local value = "titi"
        local oldValue = "toto"
        local settings = {
            setting1 = oldValue,
            setting2 = value,
        }

        ModConfig:AddKeysMissingFromBlueprint(blueprint, settings)

        D.expect(settings["setting2"]).toBe(value)
        D.expect(settings["setting1"]).toBe(oldValue)
    end)

    D.test("TestSaveSettingsForModShouldPersistRootSettings", function()
        local modUUID = TestConstants.ModuleUUIDs[1]
        local rawData = {
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "root-setting",
                    Name = "Root Setting",
                    Type = "checkbox",
                    Default = true,
                }
            }
        }

        local preprocessedData = DataPreprocessing:PreprocessData(rawData, modUUID)
        local blueprint = Blueprint:New(preprocessedData)

        local originalMods = ModConfig.mods
        local originalGetSettingsFilePath = ModConfig.GetSettingsFilePath
        local originalSaveJSONFile = JsonLayer.SaveJSONFile
        local capturedPath = nil
        local capturedData = nil

        ModConfig.mods = {
            [modUUID] = {
                blueprint = blueprint,
                settingsValues = {
                    ["root-setting"] = false,
                }
            }
        }

        ModConfig.GetSettingsFilePath = function(_self, _modUUID)
            return "mock/settings.json"
        end

        JsonLayer.SaveJSONFile = function(_self, path, data)
            capturedPath = path
            capturedData = data
        end

        local ok, err = pcall(function()
            ModConfig:SaveSettingsForMod(modUUID)
        end)

        ModConfig.mods = originalMods
        ModConfig.GetSettingsFilePath = originalGetSettingsFilePath
        JsonLayer.SaveJSONFile = originalSaveJSONFile

        if not ok then
            error(err)
        end

        D.expect(capturedPath).toBe("mock/settings.json")
        D.expect(capturedData["root-setting"]).toBe(false)
    end)

    D.test("TestSaveSettingsForModShouldFallbackToRootDefault", function()
        local modUUID = TestConstants.ModuleUUIDs[1]
        local rawData = {
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "root-setting",
                    Name = "Root Setting",
                    Type = "checkbox",
                    Default = true,
                }
            }
        }

        local preprocessedData = DataPreprocessing:PreprocessData(rawData, modUUID)
        local blueprint = Blueprint:New(preprocessedData)

        local originalMods = ModConfig.mods
        local originalGetSettingsFilePath = ModConfig.GetSettingsFilePath
        local originalSaveJSONFile = JsonLayer.SaveJSONFile
        local capturedData = nil

        ModConfig.mods = {
            [modUUID] = {
                blueprint = blueprint,
                settingsValues = {}
            }
        }

        ModConfig.GetSettingsFilePath = function(_self, _modUUID)
            return "mock/settings.json"
        end

        JsonLayer.SaveJSONFile = function(_self, _path, data)
            capturedData = data
        end

        local ok, err = pcall(function()
            ModConfig:SaveSettingsForMod(modUUID)
        end)

        ModConfig.mods = originalMods
        ModConfig.GetSettingsFilePath = originalGetSettingsFilePath
        JsonLayer.SaveJSONFile = originalSaveJSONFile

        if not ok then
            error(err)
        end

        D.expect(capturedData["root-setting"]).toBe(true)
    end)

    D.test("TestSaveSettingsForModShouldPersistNestedSettings", function()
        local modUUID = TestConstants.ModuleUUIDs[1]
        local rawData = {
            SchemaVersion = 1,
            Tabs = {
                {
                    TabId = "main-tab",
                    TabName = "Main",
                    Tabs = {
                        {
                            TabId = "nested-tab",
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

        local blueprint = Blueprint:New(DataPreprocessing:PreprocessData(rawData, modUUID))
        local originalMods = ModConfig.mods
        local originalGetSettingsFilePath = ModConfig.GetSettingsFilePath
        local originalSaveJSONFile = JsonLayer.SaveJSONFile
        local capturedData = nil

        ModConfig.mods = {
            [modUUID] = {
                blueprint = blueprint,
                settingsValues = {
                    ["nested-setting"] = false,
                }
            }
        }

        ModConfig.GetSettingsFilePath = function(_self, _modUUID)
            return "mock/settings.json"
        end

        JsonLayer.SaveJSONFile = function(_self, _path, data)
            capturedData = data
        end

        local ok, err = pcall(function()
            ModConfig:SaveSettingsForMod(modUUID)
        end)

        ModConfig.mods = originalMods
        ModConfig.GetSettingsFilePath = originalGetSettingsFilePath
        JsonLayer.SaveJSONFile = originalSaveJSONFile

        if not ok then
            error(err)
        end

        D.expect(capturedData["main-tab"]["nested-tab"]["nested-setting"]).toBe(false)
    end)

    D.test("TestLoadedSettingsRepairShouldFlattenMigrateAndValidate", function()
        local modUUID = TestConstants.ModuleUUIDs[1]
        local blueprint = Blueprint:New({
            ModUUID = modUUID,
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "list-v2-setting",
                    Type = "list_v2",
                    Default = {
                        enabled = true,
                        elements = {}
                    }
                },
                {
                    Id = "int-setting",
                    Type = "int",
                    Default = 42
                }
            }
        })

        local repaired = LoadedSettingsRepair:Repair(blueprint, {
            group = {
                ["list-v2-setting"] = { "Alpha", "Beta" },
                ["int-setting"] = "broken",
            }
        })

        D.expect(repaired["list-v2-setting"].enabled).toBe(true)
        D.expect(repaired["list-v2-setting"].elements[1].name).toBe("Alpha")
        D.expect(repaired["int-setting"]).toBe(42)
    end)

    D.test("TestLoadedSettingsRepairShouldPreserveEmptyUnknownTables", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "known-setting",
                    Type = "checkbox",
                    Default = true
                }
            }
        })

        local settings = {
            ["known-setting"] = false,
            ["unknown-empty"] = {},
            ["unknown-value"] = "remove me",
        }

        LoadedSettingsRepair:RemoveDeprecatedKeys(blueprint, settings)

        D.expect(settings["unknown-empty"]).Not.toBeNil()
        D.expect(settings["unknown-value"]).toBeNil()
    end)
end)
