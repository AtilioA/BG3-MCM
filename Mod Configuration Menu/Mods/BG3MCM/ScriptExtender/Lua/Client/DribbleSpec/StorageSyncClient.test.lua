local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")

D.describe("StorageSyncService client", { tags = { "storage-sync", "store", "unit" } }, function()
    local syncStateFixture = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function(ctx)
        syncStateFixture:Isolate(ctx)
    end)

    D.afterEach(function()
        syncStateFixture:Restore()
    end)

    D.test("TestStoreSyncFlowSendsLocalWritesAndAppliesRemoteValuesWithoutEcho", function(ctx)
        local moduleUUID = ModuleUUID
        local varName = "dribblespec_sync_flow_fixture"
        local fileName = "mcm_dribblespec_sync_flow_client.json"
        local sent = syncStateFixture.sentToServer

        ctx.stub(MCMUtils, "IsClientMainMenu", function() return false end)

        D.expect(MCM.Store.RegisterVar(varName, {
            modUUID = moduleUUID,
            storageConfig = { fileName = fileName, SyncToServer = true, SyncToClient = true },
        })).toBe(true)

        D.expect(MCM.Store.Set({ var = varName, value = "local-value", modUUID = moduleUUID })).toBe(true)
        D.expect(MCM.Store.Get({ var = varName, modUUID = moduleUUID })).toBe("local-value")
        D.expect(#sent).toBe(1)
        D.expect(sent[1]).toEqual({
            storageType = "json",
            moduleUUID = moduleUUID,
            varName = varName,
            value = "local-value",
            storageConfig = {
                fileName = fileName,
                Server = true, Client = true,
                WriteableOnServer = true, WriteableOnClient = true,
                Persistent = true, SyncToClient = true, SyncToServer = true,
            },
        })

        StorageSyncService:HandleServerSyncPayload({
            storageType = "json",
            moduleUUID = moduleUUID,
            varName = varName,
            value = "remote-value",
        })
        D.expect(MCM.Store.Get({ var = varName, modUUID = moduleUUID })).toBe("remote-value")
        D.expect(#sent).toBe(1)
    end)

    D.test("TestStoreSetInTheMainMenuKeepsTheWriteLocal", function(ctx)
        local varName = "dribblespec_sync_main_menu_fixture"
        ctx.stub(MCMUtils, "IsClientMainMenu", function() return true end)

        D.expect(MCM.Store.RegisterVar(varName, {
            modUUID = ModuleUUID,
            storageConfig = { fileName = "mcm_dribblespec_sync_main_menu.json", SyncToServer = true },
        })).toBe(true)
        D.expect(MCM.Store.Set({ var = varName, value = "menu-value", modUUID = ModuleUUID })).toBe(true)
        D.expect(MCM.Store.Get({ var = varName, modUUID = ModuleUUID })).toBe("menu-value")
        D.expect(#syncStateFixture.sentToServer).toBe(0)
    end)
end)
