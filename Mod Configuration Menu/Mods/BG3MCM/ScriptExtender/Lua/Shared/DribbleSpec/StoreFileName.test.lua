-- Covers MCM.Store JSON placement via storageConfig.fileName (ADR 0002).
-- Ext.IO cannot delete files; these tests restore the fixture files' prior bytes after each test.

-- Both contexts share disk, but each JSON handler saves its own complete in-memory copy.
local DEFAULT_FILE_NAME = "dynamic_settings.json"
local CONTEXT = Ext.IsServer() and "server" or "client"
local TEST_FILE_NAME = "mcm_dribblespec_store_file_" .. CONTEXT .. ".json"
local OTHER_FILE_NAME = "mcm_dribblespec_store_other_" .. CONTEXT .. ".json"
local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/StorageSyncState.lua")

--- Path of a file in MCM's own Store directory, as documented for storageConfig.fileName.
---@param fileName string
---@return string path
local function StoreFilePath(fileName)
    local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    return string.format("%s/Profiles/Default/%s/%s", directory, directory, fileName)
end

--- Parsed content of a Store file, or an empty table when it is missing or empty.
---@param fileName string
---@return table<string, StorageValue> data
local function ReadStoreFile(fileName)
    local content = Ext.IO.LoadFile(StoreFilePath(fileName))
    if not content or content == "" then
        return {}
    end
    return Ext.Json.Parse(content)
end

D.describe("MCM.Store fileName", { tags = { "store", "unit", "destructive" } }, function()
    local filesToRestore
    local syncStateFixture = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function()
        filesToRestore = {
            [DEFAULT_FILE_NAME] = { content = Ext.IO.LoadFile(StoreFilePath(DEFAULT_FILE_NAME)) },
        }
        syncStateFixture:Isolate()
    end)

    D.afterEach(function()
        for fileName, snapshot in pairs(filesToRestore) do
            local path = StoreFilePath(fileName)
            if Ext.IO.LoadFile(path) ~= snapshot.content then
                pcall(Ext.IO.SaveFile, path, snapshot.content or "")
            end
        end

        syncStateFixture:Restore()
    end)

    local function registerFixtureVar(varName, options)
        return MCM.Store.RegisterVar(varName, options)
    end

    local function rememberFile(fileName)
        if filesToRestore[fileName] == nil then
            filesToRestore[fileName] = { content = Ext.IO.LoadFile(StoreFilePath(fileName)) }
        end
    end

    D.test("TestStoreFileNameRoundTripsThroughNamedFile", function()
        local varName = "dribblespec_store_file_round_trip_" .. CONTEXT
        D.expect(registerFixtureVar(varName, {
            storageConfig = { fileName = TEST_FILE_NAME, SyncToClient = false, SyncToServer = false },
        })).toBe(true)

        rememberFile(TEST_FILE_NAME)
        MCM.Store.Set(varName, "stored-value")
        local namedFileValue = ReadStoreFile(TEST_FILE_NAME)[varName]
        local defaultFileValue = ReadStoreFile("dynamic_settings.json")[varName]
        local storedValue = MCM.Store.Get(varName)

        D.expect(storedValue).toBe("stored-value")
        D.expect(namedFileValue).toBe("stored-value")
        D.expect(defaultFileValue).toBeNil()
    end)

    D.test("TestStoreFileNameConflictKeepsFirstFile", function()
        local varName = "dribblespec_store_file_conflict_" .. CONTEXT
        D.expect(registerFixtureVar(varName, {
            storageConfig = { fileName = TEST_FILE_NAME, SyncToClient = false, SyncToServer = false },
        })).toBe(true)
        D.expect(registerFixtureVar(varName, {
            storageConfig = { fileName = TEST_FILE_NAME, SyncToClient = false, SyncToServer = false },
        })).toBe(true)
        D.expect(registerFixtureVar(varName, {
            storageConfig = { fileName = OTHER_FILE_NAME, SyncToClient = false, SyncToServer = false },
        })).toBe(false)

        rememberFile(TEST_FILE_NAME)
        rememberFile(OTHER_FILE_NAME)
        MCM.Store.Set(varName, 7)
        local namedFileValue = ReadStoreFile(TEST_FILE_NAME)[varName]
        local otherFileValue = ReadStoreFile(OTHER_FILE_NAME)[varName]

        D.expect(namedFileValue).toBe(7)
        D.expect(otherFileValue).toBeNil()
    end)

    D.test("TestStoreFileNameRejectsDirectoryParts", function()
        D.expect(registerFixtureVar("dribblespec_store_file_path_" .. CONTEXT,
            { storageConfig = { fileName = "sub/" .. TEST_FILE_NAME } })).toBe(false)
        D.expect(registerFixtureVar("dribblespec_store_file_path_" .. CONTEXT,
            { storageConfig = { fileName = "..\\" .. TEST_FILE_NAME } })).toBe(false)
    end)
end)
