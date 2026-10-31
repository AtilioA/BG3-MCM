-- Covers MCM.Store protection of JSON Store files that cannot be parsed (ADR 0003).
local CONTEXT = Ext.IsServer() and "server" or "client"
local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")

local UNREADABLE_CONTENT = '{"dribblespec_store_unreadable": tru'

--- Path of a file in MCM's own Store directory, as documented for storageConfig.fileName.
---@param fileName string
---@return string path
local function StoreFilePath(fileName)
    local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    return string.format("%s/Profiles/Default/%s/%s", directory, directory, fileName)
end

D.describe("MCM.Store unreadable file", { tags = { "store", "unit" } }, function()
    local syncStateFixture = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function(ctx)
        syncStateFixture:Isolate(ctx)
    end)

    D.afterEach(function()
        syncStateFixture:Restore()
    end)

    local function registerFixtureVar(varName, options)
        return MCM.Store.RegisterVar(varName, options)
    end

    D.test("TestStoreKeepsUnparsableFileUnchangedAfterSet", function()
        local fileName = "mcm_dribblespec_store_unreadable_set_" .. CONTEXT .. ".json"
        local varName = "dribblespec_store_unreadable_set_" .. CONTEXT
        Ext.IO.SaveFile(StoreFilePath(fileName), UNREADABLE_CONTENT)
        registerFixtureVar(varName, {
            storageConfig = { fileName = fileName, SyncToClient = false, SyncToServer = false },
        })

        local setResult = MCM.Store.Set(varName, true)

        D.expect(setResult).toBe(false)
        D.expect(Ext.IO.LoadFile(StoreFilePath(fileName))).toBe(UNREADABLE_CONTENT)
        D.expect(MCM.Store.Get(varName)).toBeNil()
        D.expect(MCM.Store.IsWritable(varName)).toBe(false)
    end)

    D.test("TestStoreUnparsableFileDoesNotBlockOtherFiles", function()
        local unreadableFileName = "mcm_dribblespec_store_unreadable_other_" .. CONTEXT .. ".json"
        local readableFileName = "mcm_dribblespec_store_readable_other_" .. CONTEXT .. ".json"
        local unreadableVar = "dribblespec_store_unreadable_other_" .. CONTEXT
        local readableVar = "dribblespec_store_readable_other_" .. CONTEXT
        Ext.IO.SaveFile(StoreFilePath(unreadableFileName), UNREADABLE_CONTENT)
        registerFixtureVar(unreadableVar, {
            storageConfig = { fileName = unreadableFileName, SyncToClient = false, SyncToServer = false },
        })
        registerFixtureVar(readableVar, {
            storageConfig = { fileName = readableFileName, SyncToClient = false, SyncToServer = false },
        })
        MCM.Store.Set(unreadableVar, 1)

        local setResult = MCM.Store.Set(readableVar, 2)
        local storedValue = MCM.Store.Get(readableVar)
        local writable = MCM.Store.IsWritable(readableVar)

        D.expect(setResult).toBe(true)
        D.expect(storedValue).toBe(2)
        D.expect(writable).toBe(true)
    end)

    D.test("TestStoreTreatsNonObjectJsonAsUnreadable", function()
        local fileName = "mcm_dribblespec_store_unreadable_number.json"
        Ext.IO.SaveFile(StoreFilePath(fileName), "5")
        registerFixtureVar("dribblespec_store_unreadable_number", {
            storageConfig = { fileName = fileName, SyncToClient = false, SyncToServer = false },
        })

        D.expect(MCM.Store.IsWritable("dribblespec_store_unreadable_number")).toBe(false)
        D.expect(MCM.Store.Set("dribblespec_store_unreadable_number", 1)).toBe(false)
        D.expect(Ext.IO.LoadFile(StoreFilePath(fileName))).toBe("5")
    end)

    D.test("TestRemoteValueDoesNotOverwriteUnparsableFile", function()
        local fileName = "mcm_dribblespec_store_unreadable_remote.json"
        local varName = "dribblespec_store_unreadable_remote"
        Ext.IO.SaveFile(StoreFilePath(fileName), UNREADABLE_CONTENT)
        registerFixtureVar(varName, {
            storageConfig = { fileName = fileName, SyncToClient = true, SyncToServer = true },
        })

        D.expect(StorageSyncService:ApplyRemoteValue("json", ModuleUUID, varName, "remote")).toBe(false)
        D.expect(Ext.IO.LoadFile(StoreFilePath(fileName))).toBe(UNREADABLE_CONTENT)
        D.expect(StorageSyncService:GetCachedValue("json", ModuleUUID, varName)).toBeNil()
    end)

    D.test("TestInvalidSetIntoUnparsableFileReportsFailure", function(ctx)
        local fileName = "mcm_dribblespec_store_unreadable_invalid.json"
        Ext.IO.SaveFile(StoreFilePath(fileName), UNREADABLE_CONTENT)
        registerFixtureVar("dribblespec_store_unreadable_invalid", {
            type = "number", default = 1,
            storageConfig = { fileName = fileName, SyncToClient = false, SyncToServer = false },
        })

        D.expect(MCM.Store.Set("dribblespec_store_unreadable_invalid", "bad")).toBe(false)
        D.expect(Ext.IO.LoadFile(StoreFilePath(fileName))).toBe(UNREADABLE_CONTENT)
        D.expect(#syncStateFixture.emittedEvents).toBe(0)
    end)
end)
