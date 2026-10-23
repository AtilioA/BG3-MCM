local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")

D.describe("StorageSyncService", { tags = { "storage-sync", "unit" } }, function()
    D.test("TestBootstrapRequestSendsPayloadOnStoreBootstrapChannel", function(ctx)
        StorageSyncService:ResetForTests()
        StorageSyncService:SetCachedValue("json", "mod-1", "k", "v")

        local sent = nil
        ctx.stub(ChunkedNet, "SendJSONToUser", function(...)
            sent = { ... }
        end)

        local response = StorageSyncService:HandleBootstrapRequest(nil, 7)

        D.expect(response).toEqual({ success = true })
        D.expect(sent[1]).toBe(7)
        D.expect(sent[2].Channel).toBe("MCM_Server_Send_Store_Bootstrap")
        D.expect(sent[3].stores.json["mod-1"]["k"]).toBe("v")
    end)

    D.test("TestStorageSyncCacheKeyedByStorageType", function(ctx)
        StorageSyncService:ResetForTests()

        StorageSyncService:SetCachedValue("json", "mod-1", "k", "json-v")
        StorageSyncService:SetCachedValue("yaml", "mod-1", "k", "yaml-v")

        D.expect(StorageSyncService:GetCachedValue("json", "mod-1", "k")).toBe("json-v")
        D.expect(StorageSyncService:GetCachedValue("yaml", "mod-1", "k")).toBe("yaml-v")
    end)

    D.test("TestStorageSyncNoLoopGuards", function(ctx)
        StorageSyncService:ResetForTests()
        StorageSyncService:BeginRemoteApply()
        D.expect(StorageSyncService:CanBroadcastLocalWrite({ SyncToClient = true })).toBe(false)
        StorageSyncService:EndRemoteApply()

        D.expect(StorageSyncService:CanBroadcastLocalWrite({ SyncToClient = true })).toBe(true)
        D.expect(StorageSyncService:CanBroadcastLocalWrite({ SyncToClient = false })).toBe(false)

        D.expect(StorageSyncService:ShouldApplyOnClient(7, 7)).toBe(false)
        D.expect(StorageSyncService:ShouldApplyOnClient(7, 8)).toBe(true)
    end)

    D.test("TestStorageSyncShouldApplyOnClientWhenOriginIsNil", function(ctx)
        StorageSyncService:ResetForTests()
        D.expect(StorageSyncService:ShouldApplyOnClient(nil, 8)).toBe(true)
    end)

    D.test("TestStorageSyncShouldApplyOnClientWhenBothNil", function(ctx)
        StorageSyncService:ResetForTests()
        D.expect(StorageSyncService:ShouldApplyOnClient(nil, nil)).toBe(true)
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
        StorageSyncService:ResetForTests()
        StorageSyncService:SetCachedValue("json", TestConstants.ModuleUUIDs[1], "cached-key", "cached-value")

        local value = JsonAdapter:GetValue("cached-key", TestConstants.ModuleUUIDs[1], nil)
        D.expect(value).toBe("cached-value")
    end)

    D.test("TestStorageSyncBootstrapPayloadIsDeepCopy", function(ctx)
        StorageSyncService:ResetForTests()
        StorageSyncService:SetCachedValue("json", "mod-1", "k", "v")

        local payload = StorageSyncService:BuildBootstrapPayload()
        D.expect(payload.stores.json["mod-1"]["k"]).toBe("v")
        payload.stores.json["mod-1"]["k"] = "mutated"

        D.expect(StorageSyncService:GetCachedValue("json", "mod-1", "k")).toBe("v")
    end)
end)
