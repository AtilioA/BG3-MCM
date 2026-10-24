-- Covers where remote Store values are persisted: only registered JSON variables are written, in their registered file (ticket 07).
-- Ext.IO cannot delete files; these tests restore the fixture file's prior bytes after each test.

local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/StorageSyncState.lua")

local CONTEXT = Ext.IsServer() and "server" or "client"
local TEST_FILE_NAME = "mcm_dribblespec_sync_file_" .. CONTEXT .. ".json"
local DEFAULT_FILE_NAME = "dynamic_settings.json"

--- Path of a file in MCM's own Store directory.
---@param fileName string
---@return string path
local function StoreFilePath(fileName)
    local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    return string.format("%s/Profiles/Default/%s/%s", directory, directory, fileName)
end

--- Raw content of a file in MCM's own Store directory, or an empty string when it is missing.
---@param fileName string
---@return string content
local function ReadStoreFileContent(fileName)
    return Ext.IO.LoadFile(StoreFilePath(fileName)) or ""
end

--- Parsed content of a Store file, or an empty table when it is missing or empty.
---@param fileName string
---@return table<string, StorageValue> data
local function ReadStoreFile(fileName)
    local content = ReadStoreFileContent(fileName)
    if content == "" then
        return {}
    end
    return Ext.Json.Parse(content)
end

D.describe("StorageSync registration", { tags = { "storage-sync", "store", "unit", "destructive" } }, function()
    local varsToClear
    local filesToRestore
    local syncStateFixture = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function()
        varsToClear = {}
        filesToRestore = {}
        syncStateFixture:Isolate()
    end)

    D.afterEach(function()
        for _, varName in ipairs(varsToClear) do
            pcall(MCM.Store.Set, { var = varName, value = nil, modUUID = ModuleUUID })
        end

        for fileName, snapshot in pairs(filesToRestore) do
            pcall(Ext.IO.SaveFile, StoreFilePath(fileName), snapshot.content or "")
        end

        syncStateFixture:Restore()
    end)

    local function registerFixtureVar(varName, options)
        table.insert(varsToClear, varName)
        return MCM.Store.RegisterVar(varName, options)
    end

    local function rememberFile(fileName)
        if filesToRestore[fileName] == nil then
            filesToRestore[fileName] = { content = Ext.IO.LoadFile(StoreFilePath(fileName)) }
        end
    end

    D.test("TestRemoteJsonValueForUnregisteredVariableIsNotWritten", function(ctx)
        local varName = "dribblespec_sync_unregistered_" .. CONTEXT
        local defaultBefore = ReadStoreFileContent(DEFAULT_FILE_NAME)
        local namedBefore = ReadStoreFileContent(TEST_FILE_NAME)
        local warnings = {}
        ctx.stub(Mods.BG3MCM, "MCMWarn", function(_, fmt, ...)
            table.insert(warnings, string.format(fmt, ...))
        end)

        -- The payload's fileName must not decide placement for an unregistered variable.
        local applied = StorageSyncService:ApplyRemoteValue("json", ModuleUUID, varName, "remote-value",
            { fileName = TEST_FILE_NAME })

        local warning = table.concat(warnings, "\n")
        D.expect(applied).toBe(false)
        D.expect(ReadStoreFileContent(DEFAULT_FILE_NAME)).toBe(defaultBefore)
        D.expect(ReadStoreFileContent(TEST_FILE_NAME)).toBe(namedBefore)
        D.expect(StorageSyncService:GetCachedValue("json", ModuleUUID, varName)).toBeNil()
        D.expect(warning:find(ModuleUUID, 1, true) ~= nil).toBeTruthy()
        D.expect(warning:find(varName, 1, true) ~= nil).toBeTruthy()
    end)

    D.test("TestRemoteJsonValueForRegisteredVariableGoesToRegisteredFile", function()
        local varName = "dribblespec_sync_registered_file_" .. CONTEXT
        rememberFile(TEST_FILE_NAME)
        -- SyncToServer lets the server context accept the value; no client echo is needed here.
        D.expect(registerFixtureVar(varName, {
            storageConfig = { fileName = TEST_FILE_NAME, SyncToServer = true, SyncToClient = false },
        })).toBe(true)

        local applied = StorageSyncService:ApplyRemoteValue("json", ModuleUUID, varName, "remote-value")
        local namedFileValue = ReadStoreFile(TEST_FILE_NAME)[varName]
        local defaultFileValue = ReadStoreFile(DEFAULT_FILE_NAME)[varName]

        D.expect(applied).toBe(true)
        D.expect(namedFileValue).toBe("remote-value")
        D.expect(defaultFileValue).toBeNil()
    end)

    D.test("TestRemoteModVarValueIsNotWrittenToJsonFiles", function()
        local defaultBefore = ReadStoreFileContent(DEFAULT_FILE_NAME)
        local varName = "dribblespec_sync_modvar_" .. CONTEXT

        local applied = StorageSyncService:ApplyRemoteValue("modvar", ModuleUUID, varName, 1)

        D.expect(applied).toBe(false)
        D.expect(ReadStoreFileContent(DEFAULT_FILE_NAME)).toBe(defaultBefore)
    end)
end)
