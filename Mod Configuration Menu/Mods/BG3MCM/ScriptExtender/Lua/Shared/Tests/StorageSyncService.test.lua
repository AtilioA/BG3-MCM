local StorageSyncService = require("Shared/DynamicSettings/Services/StorageSyncService")
local JsonAdapter = require("Shared/DynamicSettings/Adapters/JsonAdapter")

TestSuite.RegisterTests("StorageSyncService", {
    "TestStoreSyncChannelsExist",
    "TestStorageSyncCacheKeyedByStorageType",
    "TestStorageSyncNoLoopGuards",
    "TestStorageSyncShouldApplyOnClientWhenOriginIsNil",
    "TestJsonDefaultsMirrorModVarSyncSemantics",
    "TestJsonGetPrefersSyncedCache",
    "TestStorageSyncBootstrapPayloadIsDeepCopy",
})

function TestStoreSyncChannelsExist()
    TestSuite.Assert(NetChannels.MCM_CLIENT_SET_STORE_VALUE ~= nil)
    TestSuite.Assert(NetChannels.MCM_SERVER_SYNC_STORE_VALUE ~= nil)
    TestSuite.Assert(NetChannels.MCM_CLIENT_REQUEST_STORE_BOOTSTRAP ~= nil)
    TestSuite.Assert(NetChannels.MCM_SERVER_SEND_STORE_BOOTSTRAP ~= nil)
end

function TestStorageSyncCacheKeyedByStorageType()
    StorageSyncService:ResetForTests()

    StorageSyncService:SetCachedValue("json", "mod-1", "k", "json-v")
    StorageSyncService:SetCachedValue("yaml", "mod-1", "k", "yaml-v")

    TestSuite.AssertEquals(StorageSyncService:GetCachedValue("json", "mod-1", "k"), "json-v")
    TestSuite.AssertEquals(StorageSyncService:GetCachedValue("yaml", "mod-1", "k"), "yaml-v")
end

function TestStorageSyncNoLoopGuards()
    StorageSyncService:ResetForTests()
    StorageSyncService:BeginRemoteApply()
    TestSuite.AssertEquals(StorageSyncService:CanBroadcastLocalWrite({ SyncToClient = true }), false)
    StorageSyncService:EndRemoteApply()

    TestSuite.AssertEquals(StorageSyncService:ShouldApplyOnClient(7, 7), false)
    TestSuite.AssertEquals(StorageSyncService:ShouldApplyOnClient(7, 8), true)
end

function TestStorageSyncShouldApplyOnClientWhenOriginIsNil()
    StorageSyncService:ResetForTests()
    TestSuite.AssertEquals(StorageSyncService:ShouldApplyOnClient(nil, 8), true)
end

function TestJsonDefaultsMirrorModVarSyncSemantics()
    local cfg = JsonAdapter:ResolveConfig(nil)
    TestSuite.AssertEquals(cfg.SyncToClient, true)
    TestSuite.AssertEquals(cfg.SyncToServer, false)
    TestSuite.AssertEquals(cfg.Server, true)
    TestSuite.AssertEquals(cfg.Client, true)
end

function TestJsonGetPrefersSyncedCache()
    StorageSyncService:ResetForTests()
    StorageSyncService:SetCachedValue("json", TestConstants.ModuleUUIDs[1], "cached-key", "cached-value")

    local value = JsonAdapter:GetValue("cached-key", TestConstants.ModuleUUIDs[1], nil)
    TestSuite.AssertEquals(value, "cached-value")
end

function TestStorageSyncBootstrapPayloadIsDeepCopy()
    StorageSyncService:ResetForTests()
    StorageSyncService:SetCachedValue("json", "mod-1", "k", "v")

    local payload = StorageSyncService:BuildBootstrapPayload()
    payload.stores.json["mod-1"]["k"] = "mutated"

    TestSuite.AssertEquals(StorageSyncService:GetCachedValue("json", "mod-1", "k"), "v")
end
