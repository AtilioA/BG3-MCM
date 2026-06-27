local StorageSyncService = require("Shared/DynamicSettings/Services/StorageSyncService")
local JsonAdapter = require("Shared/DynamicSettings/Adapters/JsonAdapter")

D.describe("StorageSyncService", { tags = { "storage-sync", "unit" } }, function()
    D.test("TestStoreSyncChannelsExist", function()
        D.expect(NetChannels.MCM_CLIENT_SET_STORE_VALUE ~= nil).toBeTruthy()
        D.expect(NetChannels.MCM_SERVER_SYNC_STORE_VALUE ~= nil).toBeTruthy()
        D.expect(NetChannels.MCM_CLIENT_REQUEST_STORE_BOOTSTRAP ~= nil).toBeTruthy()
        D.expect(NetChannels.MCM_SERVER_SEND_STORE_BOOTSTRAP ~= nil).toBeTruthy()
    end)

    D.test("TestStorageSyncCacheKeyedByStorageType", function()
        StorageSyncService:ResetForTests()

        StorageSyncService:SetCachedValue("json", "mod-1", "k", "json-v")
        StorageSyncService:SetCachedValue("yaml", "mod-1", "k", "yaml-v")

        D.expect(StorageSyncService:GetCachedValue("json", "mod-1", "k")).toBe("json-v")
        D.expect(StorageSyncService:GetCachedValue("yaml", "mod-1", "k")).toBe("yaml-v")
    end)

    D.test("TestStorageSyncNoLoopGuards", function()
        StorageSyncService:ResetForTests()
        StorageSyncService:BeginRemoteApply()
        D.expect(StorageSyncService:CanBroadcastLocalWrite({ SyncToClient = true })).toBe(false)
        StorageSyncService:EndRemoteApply()

        D.expect(StorageSyncService:ShouldApplyOnClient(7, 7)).toBe(false)
        D.expect(StorageSyncService:ShouldApplyOnClient(7, 8)).toBe(true)
    end)

    D.test("TestStorageSyncShouldApplyOnClientWhenOriginIsNil", function()
        StorageSyncService:ResetForTests()
        D.expect(StorageSyncService:ShouldApplyOnClient(nil, 8)).toBe(true)
    end)

    D.test("TestJsonDefaultsMirrorModVarSyncSemantics", function()
        local cfg = JsonAdapter:ResolveConfig(nil)
        D.expect(cfg.SyncToClient).toBe(true)
        D.expect(cfg.SyncToServer).toBe(false)
        D.expect(cfg.Server).toBe(true)
        D.expect(cfg.Client).toBe(true)
    end)

    D.test("TestJsonGetPrefersSyncedCache", function()
        StorageSyncService:ResetForTests()
        StorageSyncService:SetCachedValue("json", TestConstants.ModuleUUIDs[1], "cached-key", "cached-value")

        local value = JsonAdapter:GetValue("cached-key", TestConstants.ModuleUUIDs[1], nil)
        D.expect(value).toBe("cached-value")
    end)

    D.test("TestStorageSyncBootstrapPayloadIsDeepCopy", function()
        StorageSyncService:ResetForTests()
        StorageSyncService:SetCachedValue("json", "mod-1", "k", "v")

        local payload = StorageSyncService:BuildBootstrapPayload()
        payload.stores.json["mod-1"]["k"] = "mutated"

        D.expect(StorageSyncService:GetCachedValue("json", "mod-1", "k")).toBe("v")
    end)
end)
