-- Covers MCM.Store JSON placement via storageConfig.fileName (ADR 0002).
-- Ext.IO cannot delete files; tests clear their keys so the fixture file holds no values afterwards.

-- Both contexts share disk, but each JSON handler saves its own complete in-memory copy.
local CONTEXT = Ext.IsServer() and "server" or "client"
local TEST_FILE_NAME = "mcm_dribblespec_store_file_" .. CONTEXT .. ".json"
local OTHER_FILE_NAME = "mcm_dribblespec_store_other_" .. CONTEXT .. ".json"

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
    D.test("TestStoreFileNameRoundTripsThroughNamedFile", function()
        local varName = "dribblespec_store_file_round_trip_" .. CONTEXT
        D.expect(MCM.Store.RegisterVar(varName, { storageConfig = { fileName = TEST_FILE_NAME } })).toBe(true)

        MCM.Store.Set(varName, "stored-value")
        local namedFileValue = ReadStoreFile(TEST_FILE_NAME)[varName]
        local defaultFileValue = ReadStoreFile("dynamic_settings.json")[varName]
        local storedValue = MCM.Store.Get(varName)

        MCM.Store.Set(varName, nil)

        D.expect(storedValue).toBe("stored-value")
        D.expect(namedFileValue).toBe("stored-value")
        D.expect(defaultFileValue).toBeNil()
    end)

    D.test("TestStoreFileNameConflictKeepsFirstFile", function()
        local varName = "dribblespec_store_file_conflict_" .. CONTEXT
        D.expect(MCM.Store.RegisterVar(varName, { storageConfig = { fileName = TEST_FILE_NAME } })).toBe(true)
        D.expect(MCM.Store.RegisterVar(varName, { storageConfig = { fileName = TEST_FILE_NAME } })).toBe(true)
        D.expect(MCM.Store.RegisterVar(varName, { storageConfig = { fileName = OTHER_FILE_NAME } })).toBe(false)

        MCM.Store.Set(varName, 7)
        local namedFileValue = ReadStoreFile(TEST_FILE_NAME)[varName]
        local otherFileValue = ReadStoreFile(OTHER_FILE_NAME)[varName]

        MCM.Store.Set(varName, nil)

        D.expect(namedFileValue).toBe(7)
        D.expect(otherFileValue).toBeNil()
    end)

    D.test("TestStoreFileNameRejectsDirectoryParts", function()
        D.expect(MCM.Store.RegisterVar("dribblespec_store_file_path_" .. CONTEXT,
            { storageConfig = { fileName = "sub/" .. TEST_FILE_NAME } })).toBe(false)
        D.expect(MCM.Store.RegisterVar("dribblespec_store_file_path_" .. CONTEXT,
            { storageConfig = { fileName = "..\\" .. TEST_FILE_NAME } })).toBe(false)
    end)
end)
