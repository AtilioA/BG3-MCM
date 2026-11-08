-- Covers MCM.Store when the filesystem refuses a JSON write: the failure reaches the caller and no state advances.
local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")

local FILE_NAME = "mcm_dribblespec_store_save_failure.json"
local SYNCED = { fileName = FILE_NAME, SyncToClient = true, SyncToServer = true }

--- Path of the test file in MCM's own Store directory.
---@return string path
local function StoreFilePath()
    local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    return string.format("%s/Profiles/Default/%s/%s", directory, directory, FILE_NAME)
end

D.describe("MCM.Store save failure", { tags = { "store", "unit" } }, function()
    local fixture = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function(ctx)
        fixture:Isolate(ctx)
    end)

    D.afterEach(function()
        fixture:Restore()
    end)

    --- Make the sandbox's file writes fail until the returned function allows them again.
    ---@param ctx table DribbleSpec test context
    ---@return fun() allow
    -- bg3-lint: allow BG3-ENGINE-WRITE -- the SaveFile result is the contract under test, and the Sandbox already stubs this function
    local function FailWrites(ctx)
        local failing = true
        local sandboxSave = Ext.IO.SaveFile
        ctx.stub(Ext.IO, "SaveFile", function(path, content)
            if failing then return false end
            return sandboxSave(path, content)
        end)
        return function() failing = false end
    end

    --- Clear what the successful setup write recorded.
    local function ClearSignals()
        fixture.emittedEvents = {}
        fixture.sentToClients = {}
        fixture.sentToServer = {}
    end

    D.test("TestFailedWriteReturnsFalseAndKeepsPreviousValue", function(ctx)
        MCM.Store.RegisterVar("kept", { storageConfig = SYNCED })
        D.expect(MCM.Store.Set("kept", "old")).toBe(true)
        local fileBefore = Ext.IO.LoadFile(StoreFilePath())
        ClearSignals()
        FailWrites(ctx)

        D.expect(MCM.Store.Set("kept", "new")).toBe(false)

        D.expect(MCM.Store.Get("kept")).toBe("old")
        D.expect(StorageSyncService:GetCachedValue("json", ModuleUUID, "kept")).toBe("old")
        D.expect(Ext.IO.LoadFile(StoreFilePath())).toBe(fileBefore)
        D.expect(#fixture.emittedEvents).toBe(0)
        D.expect(#fixture.sentToClients).toBe(0)
        D.expect(#fixture.sentToServer).toBe(0)
        D.expect(MCM.Store.IsWritable("kept")).toBe(true)
    end)

    D.test("TestFailedFirstWriteLeavesTheVariableUnset", function(ctx)
        MCM.Store.RegisterVar("fresh", { storageConfig = SYNCED })
        FailWrites(ctx)

        D.expect(MCM.Store.Set("fresh", "new")).toBe(false)

        D.expect(MCM.Store.Get("fresh")).toBeNil()
        D.expect(StorageSyncService:GetCachedValue("json", ModuleUUID, "fresh")).toBeNil()
    end)

    D.test("TestFailedWriteDoesNotReachALaterSave", function(ctx)
        MCM.Store.RegisterVar("lost", { storageConfig = SYNCED })
        MCM.Store.RegisterVar("later", { storageConfig = SYNCED })
        local allow = FailWrites(ctx)
        D.expect(MCM.Store.Set("lost", "never")).toBe(false)
        allow()

        D.expect(MCM.Store.Set("later", 1)).toBe(true)

        local saved = Ext.Json.Parse(Ext.IO.LoadFile(StoreFilePath()))
        D.expect(saved.later).toBe(1)
        D.expect(saved.lost).toBeNil()
    end)

    D.test("TestFailedRemoteApplyIsReportedAndNotCached", function(ctx)
        MCM.Store.RegisterVar("remote", { storageConfig = SYNCED })
        FailWrites(ctx)

        D.expect(StorageSyncService:ApplyRemoteValue("json", ModuleUUID, "remote", 5)).toBe(false)

        D.expect(StorageSyncService:GetCachedValue("json", ModuleUUID, "remote")).toBeNil()
        D.expect(StorageSyncService._applyingRemote).toBe(false)
    end)
end)
