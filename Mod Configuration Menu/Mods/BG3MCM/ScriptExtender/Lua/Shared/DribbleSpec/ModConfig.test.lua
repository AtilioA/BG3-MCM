local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/StorageSyncState.lua")

D.describe("ModConfig", { tags = { "modconfig", "unit" } }, function()
    local originalMods
    local syncStateFixture = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function(ctx)
        syncStateFixture:Isolate(ctx)
        originalMods = ModConfig.mods
    end)

    D.afterEach(function()
        ModConfig.mods = originalMods
        syncStateFixture:Restore()
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

    D.test("TestSaveAndReloadSettingsForModRestoresSavedValues", function(ctx)
        local modUUID = ModuleUUID
        local settingId = "save-reload-checkbox"
        local blueprint = Blueprint:New({
            ModUUID = modUUID,
            SchemaVersion = 1,
            Settings = {
                { Id = settingId, Type = "checkbox", Default = true },
            },
        })
        local path = "DribbleSpec/save-reload.json"
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
end)
