local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")
local CONTEXT = Ext.IsServer() and "server" or "client"

--- Path of a named file in MCM's Store directory.
---@param fileName string
---@return string path
local function StoreFilePath(fileName)
    local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    return string.format("%s/Profiles/Default/%s/%s", directory, directory, fileName)
end

D.describe("StorageSyncService", { tags = { "storage-sync", "store", "unit" } }, function()
    local syncStateFixture = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function(ctx)
        syncStateFixture:Isolate(ctx)
    end)

    D.afterEach(function()
        syncStateFixture:Restore()
    end)

    D.test("TestBootstrapRequestSendsPayloadOnStoreBootstrapChannel", function(ctx)
        StorageSyncService:SetCachedValue("json", "mod-1", "k", "v")

        local sent = {}
        ctx.stub(ChunkedNet, "SendJSONToUser", function(...)
            table.insert(sent, { ... })
        end)

        local response = StorageSyncService:HandleBootstrapRequest(nil, 7)

        D.expect(response).toEqual({ success = true })
        D.expect(#sent).toBe(1)
        D.expect(sent[1][1]).toBe(7)
        D.expect(sent[1][2].Channel).toBe("MCM_Server_Send_Store_Bootstrap")
        D.expect(sent[1][3]).toEqual({ stores = { json = { ["mod-1"] = { k = "v" } } } })
    end)

    D.test("TestStorageSyncCacheKeyedByStorageType", function(ctx)
        StorageSyncService:SetCachedValue("json", "mod-1", "k", "json-v")
        StorageSyncService:SetCachedValue("yaml", "mod-1", "k", "yaml-v")
        StorageSyncService:SetCachedValue("json", "mod-1", "false-value", false)

        D.expect(StorageSyncService:GetCachedValue("json", "mod-1", "k")).toBe("json-v")
        D.expect(StorageSyncService:GetCachedValue("yaml", "mod-1", "k")).toBe("yaml-v")
        D.expect(StorageSyncService:GetCachedValue("json", "mod-1", "false-value")).toBe(false)
    end)

    D.test("TestStorageSyncNoLoopGuards", function(ctx)
        StorageSyncService:BeginRemoteApply()
        D.expect(StorageSyncService:CanBroadcastLocalWrite({ SyncToClient = true })).toBe(false)
        D.expect(StorageSyncService:CanClientSendToServer({ SyncToServer = true })).toBe(false)
        StorageSyncService:EndRemoteApply()

        D.expect(StorageSyncService:CanBroadcastLocalWrite({ SyncToClient = true })).toBe(true)
        D.expect(StorageSyncService:CanBroadcastLocalWrite({ SyncToClient = false })).toBe(false)
        D.expect(StorageSyncService:CanBroadcastLocalWrite(nil)).toBe(false)
        D.expect(StorageSyncService:CanClientSendToServer({ SyncToServer = true })).toBe(true)
        D.expect(StorageSyncService:CanClientSendToServer({ SyncToServer = false })).toBe(false)
        D.expect(StorageSyncService:CanClientSendToServer(nil)).toBe(false)
    end)

    D.test("TestStoreSyncFlowSendsLocalWritesAndAppliesRemoteValuesWithoutEcho", function(ctx)
        ctx.requireClient()

        local moduleUUID = ModuleUUID
        local varName = "dribblespec_sync_flow_fixture"
        local fileName = "mcm_dribblespec_sync_flow_" .. CONTEXT .. ".json"
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
        ctx.requireClient()

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

    D.test("TestJsonResolveConfigAppliesOverridesOnDefaults", function(ctx)
        local cfg = JsonAdapter:ResolveConfig({ SyncToServer = true, Client = false })
        D.expect(cfg).toEqual({
            Server = true,
            Client = false,
            WriteableOnServer = true,
            WriteableOnClient = true,
            Persistent = true,
            SyncToClient = true,
            SyncToServer = true,
        })
    end)

    D.test("TestJsonGetPrefersSyncedCache", function(ctx)
        local moduleUUID = ModuleUUID
        local varName = "dribblespec_cache_false_conflict_" .. CONTEXT
        local fileName = "mcm_dribblespec_cache_conflict_" .. CONTEXT .. ".json"
        local path = StoreFilePath(fileName)

        D.expect(JsonAdapter:EnsureRegistered(varName, moduleUUID, { fileName = fileName })).toBe(true)
        D.expect(Ext.IO.SaveFile(path, Ext.Json.Stringify({ [varName] = true }))).toBe(true)
        StorageSyncService:SetCachedValue("json", moduleUUID, varName, false)

        local value = JsonAdapter:GetValue(varName, moduleUUID, nil)
        D.expect(value).toBe(false)
    end)

    D.test("TestStorageSyncBootstrapPayloadIsDeepCopy", function(ctx)
        StorageSyncService:SetCachedValue("json", "mod-1", "k", "v")
        StorageSyncService:SetCachedValue("json", "mod-1", "nested", {
            preferences = {
                enabled = true,
            },
        })

        local payload = StorageSyncService:BuildBootstrapPayload()
        D.expect(payload.stores.json["mod-1"]["k"]).toBe("v")
        D.expect(payload.stores.json["mod-1"]["nested"]).toEqual({
            preferences = { enabled = true },
        })
        payload.stores.json["mod-1"]["k"] = "mutated"
        payload.stores.json["mod-1"]["nested"].preferences.enabled = false

        D.expect(StorageSyncService:GetCachedValue("json", "mod-1", "k")).toBe("v")
        D.expect(StorageSyncService:GetCachedValue("json", "mod-1", "nested")).toEqual({
            preferences = { enabled = true },
        })
    end)
end)

D.describe("StorageSyncService remote values", { tags = { "storage-sync", "store", "unit" } }, function()
    local syncStateFixture = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)
    local FILE_NAME = "mcm_dribblespec_sync_remote.json"

    D.beforeEach(function(ctx)
        syncStateFixture:Isolate(ctx)
    end)

    D.afterEach(function()
        syncStateFixture:Restore()
    end)

    local function register(varName, syncToClient, syncToServer)
        D.expect(MCM.Store.RegisterVar(varName, {
            storageConfig = { fileName = FILE_NAME, SyncToClient = syncToClient, SyncToServer = syncToServer },
        })).toBe(true)
    end

    local function clientSet(varName, value, userID)
        return StorageSyncService:HandleClientSet(
            { storageType = "JSON", moduleUUID = ModuleUUID, varName = varName, value = value }, userID)
    end

    local function fileValue(varName)
        return Ext.Json.Parse(Ext.IO.LoadFile(StoreFilePath(FILE_NAME)) or "{}")[varName]
    end

    D.test("TestClientSetRejectsInvalidRequests", function()
        D.expect(StorageSyncService:HandleClientSet(nil, 1)).toEqual({ success = false, error = "Invalid payload" })
        D.expect(StorageSyncService:HandleClientSet("{", 1)).toEqual({ success = false, error = "Invalid payload" })
        D.expect(StorageSyncService:HandleClientSet('"text"', 1)).toEqual({ success = false, error = "Invalid payload" })
        local missing = { success = false, error = "Missing storageType/moduleUUID/varName" }
        D.expect(StorageSyncService:HandleClientSet({ moduleUUID = ModuleUUID, varName = "v" }, 1)).toEqual(missing)
        D.expect(StorageSyncService:HandleClientSet({ storageType = "json", varName = "v" }, 1)).toEqual(missing)
        D.expect(StorageSyncService:HandleClientSet({ storageType = "json", moduleUUID = ModuleUUID }, 1)).toEqual(missing)
        D.expect(StorageSyncService:HandleClientSet({ storageType = "yaml", moduleUUID = ModuleUUID, varName = "v" }, 1))
            .toEqual({ success = false, error = "Unknown storageType" })
        D.expect(clientSet("unregistered", 1, 1)).toEqual({ success = false, error = "Failed to apply value" })
        D.expect(#syncStateFixture.sentToClients).toBe(0)
    end)

    D.test("TestClientSetAcceptsJsonStringPayload", function(ctx)
        ctx.requireServer()
        register("from_string", false, true)

        local payload = Ext.Json.Stringify({ storageType = "json", moduleUUID = ModuleUUID, varName = "from_string", value = 4 })

        D.expect(StorageSyncService:HandleClientSet(payload, 1)).toEqual({ success = true })
        D.expect(fileValue("from_string")).toBe(4)
    end)

    D.test("TestServerAcceptsOnlyVariablesSyncedToServer", function(ctx)
        ctx.requireServer()
        register("to_server", false, true)
        register("to_client", true, false)

        D.expect(clientSet("to_client", "remote", 1)).toEqual({ success = false, error = "Failed to apply value" })
        D.expect(clientSet("to_server", "remote", 1)).toEqual({ success = true })

        D.expect(fileValue("to_client")).toBeNil()
        D.expect(MCM.Store.Get("to_server")).toBe("remote")
        D.expect(fileValue("to_server")).toBe("remote")
        D.expect(#syncStateFixture.sentToClients).toBe(0)
    end)

    D.test("TestServerRebroadcastsClientSetToOtherClientsOnce", function(ctx)
        ctx.requireServer()
        syncStateFixture:StubConnectedUsers(ctx)
        register("shared", true, true)

        D.expect(clientSet("shared", "first", 3)).toEqual({ success = true })
        D.expect(syncStateFixture:SentUserIDs()).toEqual({ 1, 2 })
        D.expect(syncStateFixture.sentToClients[1].payload.value).toBe("first")

        syncStateFixture.sentToClients = {}
        D.expect(clientSet("shared", "second", 1)).toEqual({ success = true })
        D.expect(syncStateFixture:SentUserIDs()).toEqual({ 2 })

        -- After a remote apply, a local write broadcasts again.
        syncStateFixture.sentToClients = {}
        MCM.Store.Set("shared", "local")
        D.expect(syncStateFixture:SentUserIDs()).toEqual({ 1, 2 })
    end)

    D.test("TestBootstrapPayloadAppliesSyncedValues", function()
        local syncsHere = Ext.IsServer() and { false, true } or { true, false }
        register("boot_synced", syncsHere[1], syncsHere[2])
        register("boot_local", false, false)

        StorageSyncService:HandleBootstrapPayload(nil)
        StorageSyncService:HandleBootstrapPayload(Ext.Json.Stringify({
            stores = { JSON = { [ModuleUUID] = { boot_synced = "remote", boot_local = "remote" } } },
        }))

        D.expect(MCM.Store.Get("boot_synced")).toBe("remote")
        D.expect(MCM.Store.Get("boot_local")).toBeNil()
    end)

    D.test("TestServerSyncPayloadAppliesValueWithoutOrigin", function()
        local syncsHere = Ext.IsServer() and { false, true } or { true, false }
        register("pushed", syncsHere[1], syncsHere[2])

        StorageSyncService:HandleServerSyncPayload(nil)
        StorageSyncService:HandleServerSyncPayload({
            storageType = "json", moduleUUID = ModuleUUID, varName = "pushed", value = "remote",
        })

        D.expect(MCM.Store.Get("pushed")).toBe("remote")
        D.expect(fileValue("pushed")).toBe("remote")
    end)

    D.test("TestBootstrapIncludesPersistedValuesOfRegisteredFilesOnly", function()
        Ext.IO.SaveFile(StoreFilePath(FILE_NAME), Ext.Json.Stringify({ persisted = "disk", stale = "old" }))
        register("persisted", false, false)
        D.expect(MCM.Store.RegisterVar("stale", { storageConfig = { fileName = "mcm_dribblespec_sync_other.json" } }))
            .toBe(true)
        MCM.Store.Get("persisted")
        MCM.Store.Get("stale")
        StorageSyncService:SetCachedValue("json", ModuleUUID, "cached", "memory")

        StorageSyncService:HandleBootstrapRequest(nil, 7)

        local sends = syncStateFixture.bootstrapSends
        D.expect(#sends).toBe(1)
        D.expect(sends[1].userID).toBe(7)
        D.expect(sends[1].payload.stores.json[ModuleUUID]).toEqual({ persisted = "disk", cached = "memory" })
    end)
end)
