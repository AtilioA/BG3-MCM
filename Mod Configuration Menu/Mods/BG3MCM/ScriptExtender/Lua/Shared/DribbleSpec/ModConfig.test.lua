local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/StorageSyncState.lua")

D.describe("ModConfig", { tags = { "modconfig", "blueprint", "unit" } }, function()
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

    D.test("LoadSettingsForMod saves repaired settings back to the file", function(ctx)
        local blueprint = Blueprint:New({
            ModUUID = ModuleUUID,
            SchemaVersion = 1,
            Settings = { { Id = "repaired-checkbox", Type = "checkbox", Default = true } },
        })
        local path = "DribbleSpec/repaired-settings.json"
        syncStateFixture.files[path] = "{}"
        ModConfig.mods = { [ModuleUUID] = { blueprint = blueprint } }
        ctx.stub(ModConfig, "GetSettingsFilePath", function()
            return path
        end)

        ModConfig:LoadSettingsForMod(ModuleUUID, blueprint)

        D.expect(ModConfig.mods[ModuleUUID].settingsValues).toEqual({ ["repaired-checkbox"] = true })
        D.expect(Ext.Json.Parse(syncStateFixture.files[path])).toEqual({ ["repaired-checkbox"] = true })
    end)

    D.test("LoadSettingsForMod saves blueprint defaults when the file is missing", function(ctx)
        local blueprint = Blueprint:New({
            ModUUID = ModuleUUID,
            SchemaVersion = 1,
            Settings = { { Id = "default-checkbox", Type = "checkbox", Default = true } },
        })
        local path = "DribbleSpec/missing-settings.json"
        ModConfig.mods = { [ModuleUUID] = { blueprint = blueprint } }
        ctx.stub(ModConfig, "GetSettingsFilePath", function()
            return path
        end)

        ModConfig:LoadSettingsForMod(ModuleUUID, blueprint)

        D.expect(ModConfig.mods[ModuleUUID].settingsValues).toEqual({ ["default-checkbox"] = true })
        D.expect(Ext.Json.Parse(syncStateFixture.files[path])).toEqual({ ["default-checkbox"] = true })
    end)

    D.describe("MCM params", function()
        local paramsPath = "DribbleSpec/mcm_params.json"

        D.beforeEach(function(ctx)
            ctx.stub(ModConfig, "GetMCMParamsFilePath", function()
                return paramsPath
            end)
        end)

        D.test("LoadMCMParams creates the default params file when it is missing", function()
            local params = ModConfig:LoadMCMParams()

            D.expect(params).toEqual(ProfileManager.DefaultConfig)
            D.expect(Ext.Json.Parse(syncStateFixture.files[paramsPath])).toEqual(ProfileManager.DefaultConfig)
        end)

        D.test("LoadMCMParams returns the parsed params file", function()
            syncStateFixture.files[paramsPath] = Ext.Json.Stringify({ Features = { Profiles = { SelectedProfile = "P" } } })

            D.expect(ModConfig:LoadMCMParams()).toEqual({ Features = { Profiles = { SelectedProfile = "P" } } })
        end)

        D.test("LoadMCMParams returns nil for a malformed params file", function()
            syncStateFixture.files[paramsPath] = "{"

            D.expect(ModConfig:LoadMCMParams()).toBeNil()
        end)
    end)

    D.describe("blueprint loading", function()
        local modUUID = TestConstants.ModuleUUIDs[1]
        local blueprintPath = "Mods/DribbleSpecFixtureMod/MCM_blueprint.json"
        local originalProfileManager
        local fixtureMod
        local warnings

        -- bg3-lint: allow BG3-ENGINE-WRITE -- the loader reads the mod list and mod data from Ext.Mod; tests need a fixture mod there
        D.beforeEach(function(ctx)
            originalProfileManager = ModConfig.profileManager
            ModConfig.mods = {}
            warnings = {}
            fixtureMod = {
                Info = {
                    Directory = "DribbleSpecFixtureMod",
                    Name = "DribbleSpec Fixture Mod",
                    Author = "DribbleSpec Fixture Author",
                    ModuleUUID = modUUID,
                    ModVersion = { 1, 2, 3, 4 },
                },
                Dependencies = { { ModuleUUID = ModuleUUID } },
            }
            local realGetMod = Ext.Mod.GetMod
            ctx.stub(Ext.Mod, "GetMod", function(uuid)
                if uuid == modUUID then
                    return fixtureMod
                end
                return realGetMod(uuid)
            end)
            ctx.stub(Ext.Mod, "GetLoadOrder", function()
                return { modUUID }
            end)
            ctx.stub(ModConfig, "GetMCMParamsFilePath", function()
                return "DribbleSpec/mcm_params.json"
            end)
            ctx.stub(Mods.BG3MCM, "MCMWarn", function(level, message, ...)
                if select("#", ...) > 0 then
                    message = string.format(message, ...)
                end
                table.insert(warnings, { level = level, message = message })
            end)
        end)

        D.afterEach(function()
            ModConfig.profileManager = originalProfileManager
        end)

        D.test("GetSettings loads blueprints and saves their settings nested by tab", function()
            syncStateFixture.files[blueprintPath] = Ext.Json.Stringify({
                SchemaVersion = 1,
                Tabs = {
                    {
                        TabId = "loaded-tab",
                        TabName = "Loaded",
                        Settings = { { Id = "loaded-checkbox", Name = "Loaded", Type = "checkbox", Default = true } },
                    },
                },
            })

            local mods = ModConfig:GetSettings()

            D.expect(mods).toBe(ModConfig.mods)
            for _, warning in ipairs(warnings) do
                D.expect(warning.level).Not.toBe(0)
            end
            D.expect(mods[modUUID].blueprint:GetSettingById("loaded-checkbox")).Not.toBeNil()
            D.expect(mods[modUUID].settingsValues).toEqual({ ["loaded-checkbox"] = true })
            D.expect(Ext.Json.Parse(syncStateFixture.files[ModConfig:GetSettingsFilePath(modUUID)]))
                .toEqual({ ["loaded-tab"] = { ["loaded-checkbox"] = true } })
        end)

        D.test("GetSettings drops a blueprint that fails validation", function()
            syncStateFixture.files[blueprintPath] = Ext.Json.Stringify({
                SchemaVersion = 1,
                Settings = { { Id = "root-checkbox", Name = "Root", Type = "checkbox", Default = true } },
                Tabs = { { TabId = "tab", TabName = "Tab", Settings = {} } },
            })

            D.expect(ModConfig:GetSettings()[modUUID]).toBeNil()
            local levelZeroMessages = {}
            for _, warning in ipairs(warnings) do
                if warning.level == 0 then
                    table.insert(levelZeroMessages, warning.message)
                end
            end
            D.expect(levelZeroMessages).toContain("Blueprint validation failed for mod: DribbleSpec Fixture Mod. " ..
                "Please contact DribbleSpec Fixture Author about this issue.")
        end)

        D.test("UpdateAllSettingsForMod stores and saves the new settings", function()
            ModConfig.mods = {
                [modUUID] = {
                    blueprint = Blueprint:New({
                        ModUUID = modUUID,
                        SchemaVersion = 1,
                        Settings = { { Id = "updated-checkbox", Type = "checkbox", Default = true } },
                    }),
                },
            }
            ModConfig.profileManager = ProfileManager:Create(ProfileManager.DefaultConfig)

            ModConfig:UpdateAllSettingsForMod(modUUID, { ["updated-checkbox"] = false })

            D.expect(ModConfig.mods[modUUID].settingsValues).toEqual({ ["updated-checkbox"] = false })
            D.expect(Ext.Json.Parse(syncStateFixture.files[ModConfig:GetSettingsFilePath(modUUID)]))
                .toEqual({ ["updated-checkbox"] = false })
        end)

        D.test("GetSettings returns an empty table when the params file is malformed", function()
            syncStateFixture.files["DribbleSpec/mcm_params.json"] = "{"

            D.expect(ModConfig:GetSettings()).toEqual({})
            D.expect(ModConfig.profileManager).toBe(originalProfileManager)
        end)

        D.test("LoadBlueprintForMod warns at level 3 when the blueprint is missing", function()
            ModConfig:LoadBlueprintForMod(modUUID)

            D.expect(ModConfig.mods[modUUID]).toBeNil()
            D.expect(warnings).toEqual({
                { level = 3, message = "Blueprint file not found for mod: DribbleSpec Fixture Mod" },
            })
        end)

        D.test("LoadBlueprintForMod warns at level 0 when the blueprint is malformed", function()
            syncStateFixture.files[blueprintPath] = "1"

            ModConfig:LoadBlueprintForMod(modUUID)

            D.expect(ModConfig.mods[modUUID]).toBeNil()
            D.expect(warnings).toEqual({
                {
                    level = 0,
                    message = "Failed to load MCM blueprint JSON file for mod: DribbleSpec Fixture Mod. " ..
                        "Blueprint is present but malformed. Please contact DribbleSpec Fixture Author about this issue.",
                },
            })
        end)

        D.test("LoadBlueprintForMod reports an unexpected error with its message", function(ctx)
            ctx.stub(JsonLayer, "LoadBlueprintForMod", function()
                error("boom", 0)
            end)

            ModConfig:LoadBlueprintForMod(modUUID)

            D.expect(warnings).toEqual({
                {
                    level = 0,
                    message = "An unexpected blueprint error occurred for mod: DribbleSpec Fixture Mod. Please contact " ..
                        Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue:\nboom",
                },
            })
        end)

        D.test("LoadBlueprintForMod reports an error without a value", function(ctx)
            ctx.stub(JsonLayer, "LoadBlueprintForMod", function()
                error(nil)
            end)

            ModConfig:LoadBlueprintForMod(modUUID)

            D.expect(warnings).toEqual({
                {
                    level = 0,
                    message = "An unexpected blueprint error occurred for mod: DribbleSpec Fixture Mod. Please contact " ..
                        Ext.Mod.GetMod(ModuleUUID).Info.Author .. " about this issue.",
                },
            })
        end)

        D.test("CheckMCMDependency warns only on the client", function()
            fixtureMod.Dependencies = nil

            ModConfig:CheckMCMDependency(modUUID, Blueprint:New({ ModUUID = modUUID, SchemaVersion = 1 }))

            D.expect(#warnings > 0).toBe(Ext.IsClient())
        end)

        -- The check logs only on the client.
        if Ext.IsServer() then
            return
        end

        D.describe("MCM dependency check", function()
            local function check(blueprintData)
                blueprintData.ModUUID = blueprintData.ModUUID or modUUID
                blueprintData.SchemaVersion = 1
                ModConfig:CheckMCMDependency(blueprintData.ModUUID, Blueprint:New(blueprintData))
            end

            D.test("LoadBlueprintForMod warns when a loaded mod has no dependencies", function()
                fixtureMod.Dependencies = nil
                syncStateFixture.files[blueprintPath] = Ext.Json.Stringify({
                    SchemaVersion = 1,
                    Settings = { { Id = "loaded-checkbox", Name = "Loaded", Type = "checkbox", Default = true } },
                })

                ModConfig:LoadBlueprintForMod(modUUID)

                D.expect(ModConfig.mods[modUUID]).Not.toBeNil()
                D.expect(#warnings).toBe(1)
                D.expect(warnings[1].level).toBe(0)
                D.expect(warnings[1].message:find("Mod 'DribbleSpec Fixture Mod' 1.2.3.4 does not have any dependencies", 1, true))
                    .Not.toBeNil()
            end)

            D.test("warns when the mod has no dependencies", function()
                fixtureMod.Dependencies = nil

                check({})

                D.expect(#warnings).toBe(1)
                D.expect(warnings[1].message:find("Mod 'DribbleSpec Fixture Mod' 1.2.3.4 does not have any dependencies", 1, true))
                    .Not.toBeNil()
            end)

            D.test("warns when MCM is not a dependency", function()
                fixtureMod.Dependencies = { { ModuleUUID = TestConstants.ModuleUUIDs[2] } }

                check({})

                D.expect(#warnings).toBe(1)
                D.expect(warnings[1].message:find("1.2.3.4 requires MCM but does not have MCM as a dependency", 1, true))
                    .Not.toBeNil()
            end)

            D.test("stays quiet when MCM is a dependency", function()
                fixtureMod.Dependencies = { { ModuleUUID = TestConstants.ModuleUUIDs[2] }, { ModuleUUID = ModuleUUID } }

                check({})

                D.expect(warnings).toEqual({})
            end)

            D.test("stays quiet for an optional blueprint", function()
                fixtureMod.Dependencies = nil

                check({ Optional = true })

                D.expect(warnings).toEqual({})
            end)

            -- bg3-lint: allow BG3-ENGINE-WRITE -- an invalid mod has the null UUID; Ext.Mod must return fixture data for it
            D.test("stays quiet for an invalid mod", function(ctx)
                fixtureMod.Dependencies = nil
                ctx.stub(Ext.Mod, "GetMod", function()
                    return fixtureMod
                end)

                check({ ModUUID = "00000000-0000-0000-0000-000000000000" })

                D.expect(warnings).toEqual({})
            end)

            -- bg3-lint: allow BG3-ENGINE-WRITE -- MCM's own mod data must have no dependencies for this case
            D.test("stays quiet for MCM itself", function(ctx)
                ctx.stub(Ext.Mod, "GetMod", function()
                    return { Info = { ModVersion = { 1, 0, 0, 0 } } }
                end)

                check({ ModUUID = ModuleUUID })

                D.expect(warnings).toEqual({})
            end)
        end)
    end)
end)
