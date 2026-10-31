-- Covers MCM.Store reads, writes, typed validation, and saved events through the sandboxed JSON adapter.
local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/StorageSyncState.lua")

local FILE_NAME = "mcm_dribblespec_store_values.json"
local LOCAL_ONLY = { fileName = FILE_NAME, SyncToClient = false, SyncToServer = false }

D.describe("MCM.Store values", { tags = { "store", "unit" } }, function()
    local syncStateFixture = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function(ctx)
        syncStateFixture:Isolate(ctx)
    end)

    D.afterEach(function()
        syncStateFixture:Restore()
    end)

    local function register(varName, options)
        options = options or {}
        options.storageConfig = options.storageConfig or LOCAL_ONLY
        D.expect(MCM.Store.RegisterVar(varName, options)).toBe(true)
    end

    D.test("TestStoredFalseIsReturnedAndReportedAsOldValue", function()
        register("flag", { type = "boolean", default = true })

        D.expect(MCM.Store.Set("flag", false)).toBe(true)
        D.expect(MCM.Store.Get("flag")).toBe(false)

        syncStateFixture.emittedEvents = {}
        MCM.Store.Set("flag", true)
        D.expect(syncStateFixture.emittedEvents[1].data.oldValue).toBe(false)
    end)
end)
