-- Covers MCM.Store reads, writes, typed validation, and saved events through the sandboxed JSON adapter.
local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/StorageSyncState.lua")

local FILE_NAME = "mcm_dribblespec_store_values.json"
local LOCAL_ONLY = { fileName = FILE_NAME, SyncToClient = false, SyncToServer = false }

--- Path of a file in MCM's own Store directory.
---@param fileName string
---@return string path
local function StoreFilePath(fileName)
    local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    return string.format("%s/Profiles/Default/%s/%s", directory, directory, fileName)
end

--- Parsed content of the test Store file.
---@return table<string, StorageValue> data
local function ReadStoreFile()
    return Ext.Json.Parse(Ext.IO.LoadFile(StoreFilePath(FILE_NAME)) or "{}")
end

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

    local wrongValues = {
        boolean = { right = true, wrong = 1 },
        number = { right = 2, wrong = "2" },
        string = { right = "s", wrong = false },
        table = { right = { a = 1 }, wrong = "t" },
    }
    for typeName, values in pairs(wrongValues) do
        D.test("TestSetChecksDeclaredType_" .. typeName, function()
            register("typed", { type = typeName })

            D.expect(MCM.Store.Set("typed", values.wrong)).toBe(false)
            D.expect(MCM.Store.Get("typed")).toBeNil()
            D.expect(MCM.Store.Set("typed", values.right)).toBe(true)
            D.expect(MCM.Store.Get("typed")).toEqual(values.right)
        end)
    end

    D.test("TestUnknownDeclaredTypeWarnsAndAcceptsValue", function(ctx)
        local warnings = {}
        ctx.stub(Mods.BG3MCM, "MCMWarn", function(_, fmt, ...)
            table.insert(warnings, string.format(fmt, ...))
        end)
        register("odd", { type = "integer" })

        D.expect(MCM.Store.Set("odd", 1)).toBe(true)
        D.expect(MCM.Store.Get("odd")).toBe(1)
        D.expect(warnings[1]).toBe("Unknown declared type: integer")
    end)

    D.test("TestSetRejectsValueThatFailsValidate", function(ctx)
        local warnings = {}
        ctx.stub(Mods.BG3MCM, "MCMWarn", function(_, fmt, ...)
            table.insert(warnings, string.format(fmt, ...))
        end)
        register("validated", { validate = function(value) return value > 0, "must be positive" end })

        D.expect(MCM.Store.Set("validated", -1)).toBe(false)
        D.expect(warnings[1]:find("Validation failed: must be positive", 1, true) ~= nil).toBeTruthy()
        D.expect(MCM.Store.Get("validated")).toBeNil()
        D.expect(MCM.Store.Set("validated", 1)).toBe(true)
        D.expect(MCM.Store.Get("validated")).toBe(1)
    end)

    D.test("TestSetWritesFileAndEmitsSavedEventWithOldValue", function()
        register("saved")
        MCM.Store.Set("saved", "first")
        syncStateFixture.emittedEvents = {}

        D.expect(MCM.Store.Set("saved", "second")).toBe(true)

        D.expect(ReadStoreFile().saved).toBe("second")
        D.expect(#syncStateFixture.emittedEvents).toBe(1)
        D.expect(syncStateFixture.emittedEvents[1]).toEqual({
            name = EventChannels.MCM_DYNAMIC_SETTING_SAVED,
            data = { modUUID = ModuleUUID, key = "saved", storageType = "json", oldValue = "first", value = "second" },
            bothContexts = true,
        })
    end)

    D.test("TestStoredFalseIsReturnedAndReportedAsOldValue", function()
        register("flag", { type = "boolean", default = true })

        D.expect(MCM.Store.Set("flag", false)).toBe(true)
        D.expect(MCM.Store.Get("flag")).toBe(false)

        syncStateFixture.emittedEvents = {}
        MCM.Store.Set("flag", true)
        D.expect(syncStateFixture.emittedEvents[1].data.oldValue).toBe(false)
    end)

    D.test("TestInvalidSetRevertsToDefaultAndEmitsCorrection", function()
        register("reverted", { type = "number", default = 5 })
        MCM.Store.Set("reverted", 7)
        syncStateFixture.emittedEvents = {}

        D.expect(MCM.Store.Set("reverted", "bad")).toBe(false)

        D.expect(MCM.Store.Get("reverted")).toBe(5)
        D.expect(ReadStoreFile().reverted).toBe(5)
        D.expect(syncStateFixture.emittedEvents).toEqual({ {
            name = EventChannels.MCM_DYNAMIC_SETTING_SAVED,
            data = { modUUID = ModuleUUID, key = "reverted", storageType = "json", oldValue = "bad", value = 5 },
            bothContexts = true,
        } })
    end)

    D.test("TestInvalidSetWithoutDefaultWritesNothing", function()
        register("nodefault", { type = "number" })
        MCM.Store.Set("nodefault", 7)
        syncStateFixture.emittedEvents = {}

        D.expect(MCM.Store.Set("nodefault", "bad")).toBe(false)

        D.expect(MCM.Store.Get("nodefault")).toBe(7)
        D.expect(#syncStateFixture.emittedEvents).toBe(0)
    end)

    D.test("TestGetReadsValuePersistedBeforeRegistration", function()
        Ext.IO.SaveFile(StoreFilePath(FILE_NAME), Ext.Json.Stringify({ persisted = "disk" }))
        register("persisted", { default = "default" })

        D.expect(MCM.Store.Get("persisted")).toBe("disk")
    end)

    D.test("TestGetRepairsInvalidPersistedValueWithDefault", function()
        Ext.IO.SaveFile(StoreFilePath(FILE_NAME), Ext.Json.Stringify({ repaired = "not-a-number" }))
        register("repaired", { type = "number", default = 3 })

        D.expect(MCM.Store.Get("repaired")).toBe(3)
        D.expect(ReadStoreFile().repaired).toBe(3)
    end)

    D.test("TestGetAllReturnsValidValuesAndDefaults", function()
        Ext.IO.SaveFile(StoreFilePath(FILE_NAME), Ext.Json.Stringify({ invalid = "x", stored = 1 }))
        register("stored")
        register("invalid", { type = "number" })
        register("unset")

        D.expect(MCM.Store.GetAll()).toEqual({ stored = 1 })
        D.expect(MCM.Store.GetAll("dribblespec-unknown-mod")).toEqual({})
    end)

    D.test("TestGetAllReturnsDefaultForClearedValue", function()
        register("cleared", { default = "d" })

        D.expect(MCM.Store.Set("cleared", nil)).toBe(true)

        D.expect(MCM.Store.GetAll().cleared).toBe("d")
    end)

    D.test("TestUnregisteredVariableIsNotReadableOrWritable", function(ctx)
        local warnings = {}
        ctx.stub(Mods.BG3MCM, "MCMWarn", function(_, fmt, ...)
            table.insert(warnings, string.format(fmt, ...))
        end)

        D.expect(MCM.Store.Get("unregistered")).toBeNil()
        D.expect(MCM.Store.Set("unregistered", 1)).toBe(false)
        D.expect(MCM.Store.IsWritable("unregistered")).toBe(false)

        D.expect(#warnings).toBe(3)
        D.expect(warnings[1]:find("'unregistered' not registered", 1, true) ~= nil).toBeTruthy()
        register("registered")
        warnings = {}
        MCM.Store.Get("registered")
        D.expect(#warnings).toBe(0)
    end)

    D.test("TestDiscoveryKeepsRegisteredDefinition", function()
        register("discovered", { type = "number" })

        SettingsService.RegisterDiscoveredVariable(ModuleUUID, "discovered", "json")
        SettingsService.RegisterDiscoveredVariable(ModuleUUID, "found", "json")

        D.expect(MCM.Store.Set("discovered", "text")).toBe(false)
        D.expect(SettingsService.GetStorageType(ModuleUUID, "discovered")).toBe("json")
        D.expect(SettingsService.GetStorageType(ModuleUUID, "found")).toBe("json")
    end)

    D.test("TestStoreFileIsReadOnce", function()
        Ext.IO.SaveFile(StoreFilePath(FILE_NAME), Ext.Json.Stringify({ k = "a" }))
        register("k")
        D.expect(MCM.Store.Get("k")).toBe("a")

        Ext.IO.SaveFile(StoreFilePath(FILE_NAME), Ext.Json.Stringify({ k = "b" }))

        D.expect(MCM.Store.Get("k")).toBe("a")
    end)

    D.test("TestLocalSetSyncsAcrossContextsOnlyWhenConfigured", function(ctx)
        ctx.stub(MCMUtils, "IsClientMainMenu", function() return false end)
        syncStateFixture:StubConnectedUsers(ctx)
        local synced = { fileName = FILE_NAME, SyncToClient = true, SyncToServer = true }
        register("synced", { storageConfig = synced })
        register("local")
        local sent = Ext.IsServer() and syncStateFixture.sentToClients or syncStateFixture.sentToServer

        MCM.Store.Set("local", 1)
        D.expect(#sent).toBe(0)
        MCM.Store.Set("synced", 2)

        if Ext.IsServer() then
            D.expect(syncStateFixture:SentUserIDs()).toEqual({ 1, 2 })
        else
            D.expect(#sent).toBe(1)
        end
        local payload = Ext.IsServer() and sent[1].payload or sent[1]
        D.expect(payload.varName).toBe("synced")
        D.expect(payload.value).toBe(2)
    end)

    D.test("TestGetOfUnsetTypedVariableWritesNothing", function()
        register("unset_typed", { type = "number" })

        D.expect(MCM.Store.Get("unset_typed")).toBeNil()
        D.expect(syncStateFixture.files[StoreFilePath(FILE_NAME)]).toBeNil()
    end)

    D.test("TestSavedEventOldValueIsSnapshot", function()
        register("snapshot")
        local first = { a = 1 }
        MCM.Store.Set("snapshot", first)
        syncStateFixture.emittedEvents = {}

        MCM.Store.Set("snapshot", { a = 2 })
        first.a = 99

        D.expect(syncStateFixture.emittedEvents[1].data.oldValue).toEqual({ a = 1 })
    end)

    D.test("TestLocalSetReplacesSyncedCacheValue", function()
        register("recached")
        StorageSyncService:SetCachedValue("json", ModuleUUID, "recached", "remote")

        MCM.Store.Set("recached", "local")

        D.expect(MCM.Store.Get("recached")).toBe("local")
    end)

    D.test("TestStoreForUnknownModWritesUnderUnknownDirectory", function(ctx)
        ctx.stub(Mods.BG3MCM, "MCMWarn", function() end)
        D.expect(MCM.Store.RegisterVar("orphan", { modUUID = "dribblespec-unknown-mod", storageConfig = LOCAL_ONLY }))
            .toBe(true)

        D.expect(MCM.Store.Set({ var = "orphan", value = 1, modUUID = "dribblespec-unknown-mod" })).toBe(true)

        local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
        local path = string.format("%s/Profiles/Default/UnknownDirectory/%s", directory, FILE_NAME)
        D.expect(Ext.Json.Parse(syncStateFixture.files[path])).toEqual({ orphan = 1 })
    end)
end)
