D.describe("ModConfig", { tags = { "modconfig", "unit" } }, function()
    local originalMods
    local filesToRestore = {}

    D.beforeEach(function()
        originalMods = ModConfig.mods
        filesToRestore = {}
    end)

    D.afterEach(function()
        local failures = {}
        for path, snapshot in pairs(filesToRestore) do
            if Ext.IO.LoadFile(path) ~= snapshot.content then
                local expectedContent = snapshot.content or ""
                local restored = Ext.IO.SaveFile(path, expectedContent)
                local readback = Ext.IO.LoadFile(path)
                if not restored or readback ~= expectedContent then
                    local failure = path
                    if not restored then
                        failure = failure .. " (SaveFile returned false)"
                    end
                    if readback ~= expectedContent then
                        failure = failure .. " (readback mismatch)"
                    end
                    table.insert(failures, failure)
                end
            end
        end

        ModConfig.mods = originalMods
        filesToRestore = {}

        if #failures > 0 then
            error("Failed to restore DribbleSpec ModConfig fixture files: " .. table.concat(failures, ", "))
        end
    end)

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

    D.test("TestSaveSettingsForModShouldPersistRootSettings", function(ctx)
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

        local capturedData = nil

        ModConfig.mods = {
            [modUUID] = {
                blueprint = blueprint,
                settingsValues = {
                    ["root-setting"] = false,
                }
            }
        }

        ctx.stub(ModConfig, "GetSettingsFilePath", function(_self, _modUUID)
            return "mock/settings.json"
        end)

        ctx.stub(JsonLayer, "SaveJSONFile", function(_self, path, data)
            capturedData = data
        end)

        ModConfig:SaveSettingsForMod(modUUID)

        D.expect(capturedData).toEqual({ ["root-setting"] = false })
    end)

    D.test("TestSaveSettingsForModShouldFallbackToRootDefault", function(ctx)
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

        local capturedData = nil

        ModConfig.mods = {
            [modUUID] = {
                blueprint = blueprint,
                settingsValues = {}
            }
        }

        ctx.stub(ModConfig, "GetSettingsFilePath", function(_self, _modUUID)
            return "mock/settings.json"
        end)

        ctx.stub(JsonLayer, "SaveJSONFile", function(_self, _path, data)
            capturedData = data
        end)

        ModConfig:SaveSettingsForMod(modUUID)

        D.expect(capturedData["root-setting"]).toBe(true)
    end)

    D.test("TestSaveSettingsForModShouldPersistNestedSettings", function(ctx)
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
        local capturedData = nil

        ModConfig.mods = {
            [modUUID] = {
                blueprint = blueprint,
                settingsValues = {
                    ["nested-setting"] = false,
                }
            }
        }

        ctx.stub(ModConfig, "GetSettingsFilePath", function(_self, _modUUID)
            return "mock/settings.json"
        end)

        ctx.stub(JsonLayer, "SaveJSONFile", function(_self, _path, data)
            capturedData = data
        end)

        ModConfig:SaveSettingsForMod(modUUID)

        D.expect(capturedData).toEqual({
            ["main-tab"] = { ["nested-tab"] = { ["nested-setting"] = false } },
        })
    end)

    D.test("TestSaveAndReloadSettingsForModRestoresSavedValues", { tags = { "destructive" } }, function(ctx)
        local modUUID = ModuleUUID
        local settingId = "save-reload-checkbox"
        local blueprint = Blueprint:New({
            ModUUID = modUUID,
            SchemaVersion = 1,
            Settings = {
                { Id = settingId, Type = "checkbox", Default = true },
            },
        })
        local context = Ext.IsServer() and "server" or "client"
        local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
        local path = directory .. "/DribbleSpec/save-reload-" .. context .. ".json"
        filesToRestore[path] = { content = Ext.IO.LoadFile(path) }
        local savedData
        local reloadedValue
        ModConfig.mods = {
            [modUUID] = { blueprint = blueprint, settingsValues = { [settingId] = false } },
        }
        ctx.stub(ModConfig, "GetSettingsFilePath", function()
            return path
        end)

        ModConfig:SaveSettingsForMod(modUUID)
        savedData = Ext.Json.Parse(Ext.IO.LoadFile(path))
        ModConfig.mods[modUUID].settingsValues = { [settingId] = true }
        ModConfig:LoadSettingsForMod(modUUID, blueprint)
        reloadedValue = ModConfig.mods[modUUID].settingsValues[settingId]

        D.expect(savedData).toEqual({ [settingId] = false })
        D.expect(reloadedValue).toBe(false)
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
        D.expect(repaired["list-v2-setting"].elements[2].name).toBe("Beta")
        D.expect(repaired["int-setting"]).toBe(42)
    end)

    D.test("TestLoadedSettingsRepairShouldPreserveMouseKeybindingV2", function()
        local settingId = "mouse-keybinding"
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                {
                    Id = settingId,
                    Type = "keybinding_v2",
                    Default = {
                        Keyboard = { Key = "K", ModifierKeys = {} },
                        Enabled = true,
                        AllowConflict = false,
                    }
                }
            }
        })

        local repaired = LoadedSettingsRepair:Repair(blueprint, {
            [settingId] = {
                Mouse = { Button = 5, ModifierKeys = { "LCTRL" } },
                Enabled = false,
                AllowConflict = true,
            }
        })

        D.expect(repaired[settingId]).toEqual({
            Mouse = { Button = 5, ModifierKeys = { "LCTRL" } },
            Enabled = false,
            AllowConflict = true,
        })
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

        D.expect(settings["known-setting"]).toBe(false)
        D.expect(settings["unknown-empty"]).toEqual({})
        D.expect(settings["unknown-value"]).toBeNil()
    end)
end)
