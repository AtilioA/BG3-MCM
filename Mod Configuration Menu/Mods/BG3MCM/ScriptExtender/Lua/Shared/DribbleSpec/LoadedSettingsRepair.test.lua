local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")

D.describe("LoadedSettingsRepair", { tags = { "preprocessing", "unit" } }, function()
    -- Mutation runs list "client": a mutant can reach any write or send, so both are sandboxed deny-by-default.
    local sandbox = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function(ctx)
        sandbox:Isolate(ctx)
    end)

    D.afterEach(function()
        sandbox:Restore()
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

        LoadedSettingsRepair:AddKeysMissingFromBlueprint(blueprint, settings)

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

        LoadedSettingsRepair:AddKeysMissingFromBlueprint(blueprint, settings)

        D.expect(settings["setting2"]).toBe(value)
        D.expect(settings["setting1"]).toBe(oldValue)
    end)

    D.test("TestLoadedSettingsRepairShouldFlattenMigrateAndValidate", function(ctx)
        local notifications = {}
        ctx.stub(NotificationManager, "CreateIMGUINotification", function(_self, _id, _severity, _title, _message, options)
            table.insert(notifications, options)
        end)
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
        D.expect(repaired["list-v2-setting"].elements[1].enabled).toBe(true)
        D.expect(repaired["int-setting"]).toBe(42)
        D.expect(#notifications).toBe(1)
        D.expect(notifications[1].displayOnceOnly).toBe(true)
    end)

    D.test("TestLoadedSettingsRepairShouldKeepNestedListV2AndFlattenGroups", function()
        local listValue = { enabled = false, elements = { { name = "Alpha", enabled = false } } }
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                { Id = "list-v2-setting", Type = "list_v2", Default = { enabled = true, elements = {} } },
                { Id = "enabled", Type = "checkbox", Default = false },
            }
        })

        local repaired = LoadedSettingsRepair:Repair(blueprint, {
            tab = { ["list-v2-setting"] = listValue },
            group = { enabled = true },
        })

        D.expect(repaired["list-v2-setting"]).toEqual(listValue)
        D.expect(repaired["enabled"]).toBe(true)
    end)

    D.test("TestLoadedSettingsRepairShouldUseOldIdAndDropUnknownKeys", function()
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                { Id = "new-id", OldId = "old-id", Type = "int", Default = 1 },
            }
        })

        local repaired = LoadedSettingsRepair:Repair(blueprint, { ["old-id"] = 7, ["unknown"] = 3 })

        D.expect(repaired).toEqual({ ["new-id"] = 7 })
    end)

    D.test("TestLoadedSettingsRepairShouldUseDefaultWithoutOldValue", function(ctx)
        local warn = ctx.spyOn(Mods.BG3MCM, "MCMWarn")
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                { Id = "setting", OldId = "old-setting", Type = "int", Default = 5 },
            }
        })

        local repaired = LoadedSettingsRepair:Repair(blueprint, {})

        D.expect(repaired).toEqual({ setting = 5 })
        D.expect(warn).Not.toHaveBeenCalled()
    end)

    D.test("TestLoadedSettingsRepairShouldResetNonTableListV2WithoutMigration", function(ctx)
        local notified = false
        ctx.stub(NotificationManager, "CreateIMGUINotification", function() notified = true end)
        local default = { enabled = true, elements = {} }
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                { Id = "list-v2-setting", Type = "list_v2", Default = default },
            }
        })

        local repaired = LoadedSettingsRepair:Repair(blueprint, { ["list-v2-setting"] = "legacy" })

        D.expect(repaired["list-v2-setting"]).toEqual(default)
        D.expect(notified).toBe(false)
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
