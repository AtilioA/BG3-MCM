local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")

D.describe("StorageSyncService server", { tags = { "storage-sync", "store", "unit" } }, function()
    local syncStateFixture = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)
    local FILE_NAME = "mcm_dribblespec_sync_server.json"

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
        local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
        local path = string.format("%s/Profiles/Default/%s/%s", directory, directory, FILE_NAME)
        return Ext.Json.Parse(Ext.IO.LoadFile(path) or "{}")[varName]
    end

    D.test("TestClientSetAcceptsJsonStringPayload", function()
        register("from_string", false, true)

        local payload = Ext.Json.Stringify({ storageType = "json", moduleUUID = ModuleUUID, varName = "from_string", value = 4 })

        D.expect(StorageSyncService:HandleClientSet(payload, 1)).toEqual({ success = true })
        D.expect(fileValue("from_string")).toBe(4)
    end)

    D.test("TestServerAcceptsOnlyVariablesSyncedToServer", function()
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
end)
