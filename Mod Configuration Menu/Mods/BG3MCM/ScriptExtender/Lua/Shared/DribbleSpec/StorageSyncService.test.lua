local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/StorageSyncState.lua")
local CONTEXT = Ext.IsServer() and "server" or "client"

--- Path of a named file in MCM's Store directory.
---@param fileName string
---@return string path
local function StoreFilePath(fileName)
    local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    return string.format("%s/Profiles/Default/%s/%s", directory, directory, fileName)
end

D.describe("StorageSyncService", { tags = { "storage-sync", "unit" } }, function()
    local syncStateFixture = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)
    local fileSnapshot

    D.beforeEach(function()
        fileSnapshot = nil
        syncStateFixture:Isolate()
    end)

    D.afterEach(function()
        if fileSnapshot then
            pcall(Ext.IO.SaveFile, fileSnapshot.path, fileSnapshot.content or "")
        end

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
        StorageSyncService:EndRemoteApply()

        D.expect(StorageSyncService:CanBroadcastLocalWrite({ SyncToClient = true })).toBe(true)
        D.expect(StorageSyncService:CanBroadcastLocalWrite({ SyncToClient = false })).toBe(false)

        D.expect(StorageSyncService:ShouldApplyOnClient(7, 7)).toBe(false)
        D.expect(StorageSyncService:ShouldApplyOnClient(7, 8)).toBe(true)
    end)

    D.test("TestStorageSyncShouldApplyOnClientWhenOriginIsNil", function(ctx)
        D.expect(StorageSyncService:ShouldApplyOnClient(nil, 8)).toBe(true)
    end)

    D.test("TestStorageSyncShouldApplyOnClientWhenBothNil", function(ctx)
        D.expect(StorageSyncService:ShouldApplyOnClient(nil, nil)).toBe(true)
    end)

    D.test("TestStoreSyncFlowSendsLocalWritesAndAppliesRemoteOriginsWithoutEcho", function(ctx)
        ctx.requireClient()

        local currentCharacter = _C()
        local localUserID = currentCharacter and currentCharacter.UserReservedFor
            and currentCharacter.UserReservedFor.UserID
        if type(localUserID) ~= "number" then
            ctx.skip("A client user ID is required to verify origin filtering")
        end

        local moduleUUID = TestConstants.ModuleUUIDs[1]
        local varName = "dribblespec_sync_flow_fixture"
        local sent = {}

        ctx.stub(MCMProxy, "IsMainMenu", function() return false end)
        ctx.stub(NetChannels.MCM_CLIENT_SET_STORE_VALUE, "SendToServer", function(_channel, payload)
            table.insert(sent, payload)
        end)
        ctx.stub(ModEventManager, "Emit", function() end)

        D.expect(MCM.Store.RegisterVar(varName, {
            modUUID = moduleUUID,
            storageConfig = { SyncToServer = true, SyncToClient = true },
        })).toBe(true)

        local fileHandler = JsonAdapter:_getFileHandler(moduleUUID, "dynamic_settings.json")
        fileHandler.Data = {}
        fileHandler.Loaded = true
        fileHandler.AutoSave = false

        D.expect(MCM.Store.Set({ var = varName, value = "local-value", modUUID = moduleUUID })).toBe(true)
        D.expect(MCM.Store.Get({ var = varName, modUUID = moduleUUID })).toBe("local-value")
        D.expect(#sent).toBe(1)
        D.expect(sent[1]).toEqual({
            storageType = "json",
            moduleUUID = moduleUUID,
            varName = varName,
            value = "local-value",
            storageConfig = JsonAdapter:ResolveConfig({ SyncToServer = true, SyncToClient = true }),
        })

        StorageSyncService:HandleServerSyncPayload({
            storageType = "json",
            moduleUUID = moduleUUID,
            varName = varName,
            value = "same-origin-value",
            originUserID = localUserID,
        })
        D.expect(MCM.Store.Get({ var = varName, modUUID = moduleUUID })).toBe("local-value")

        StorageSyncService:HandleServerSyncPayload({
            storageType = "json",
            moduleUUID = moduleUUID,
            varName = varName,
            value = "other-origin-value",
            originUserID = localUserID + 1,
        })
        D.expect(MCM.Store.Get({ var = varName, modUUID = moduleUUID })).toBe("other-origin-value")

        StorageSyncService:HandleServerSyncPayload({
            storageType = "json",
            moduleUUID = moduleUUID,
            varName = varName,
            value = "nil-origin-value",
        })
        D.expect(MCM.Store.Get({ var = varName, modUUID = moduleUUID })).toBe("nil-origin-value")
        D.expect(#sent).toBe(1)
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
        fileSnapshot = { path = path, content = Ext.IO.LoadFile(path) }

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
