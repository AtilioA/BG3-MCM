-- Covers where remote Store values are persisted: only registered JSON variables are written, in their registered file (ticket 07).
-- Ext.IO cannot delete files; tests clear their keys so the fixture file holds no values afterwards.

local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")

local TEST_FILE_NAME = "mcm_dribblespec_sync_file.json"
local DEFAULT_FILE_NAME = "dynamic_settings.json"

--- Raw content of a file in MCM's own Store directory, or an empty string when it is missing.
---@param fileName string
---@return string content
local function ReadStoreFileContent(fileName)
    local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    local path = string.format("%s/Profiles/Default/%s/%s", directory, directory, fileName)
    return Ext.IO.LoadFile(path) or ""
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
    D.test("TestRemoteJsonValueForUnregisteredVariableIsNotWritten", function(ctx)
        local varName = "dribblespec_sync_unregistered"
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
        local varName = "dribblespec_sync_registered_file"
        D.expect(MCM.Store.RegisterVar(varName, { storageConfig = { fileName = TEST_FILE_NAME } })).toBe(true)

        local applied = StorageSyncService:ApplyRemoteValue("json", ModuleUUID, varName, "remote-value")
        local namedFileValue = ReadStoreFile(TEST_FILE_NAME)[varName]
        local defaultFileValue = ReadStoreFile(DEFAULT_FILE_NAME)[varName]

        MCM.Store.Set(varName, nil)

        D.expect(applied).toBe(true)
        D.expect(namedFileValue).toBe("remote-value")
        D.expect(defaultFileValue).toBeNil()
    end)

    D.test("TestRemoteModVarValueIsNotWrittenToJsonFiles", function()
        local defaultBefore = ReadStoreFileContent(DEFAULT_FILE_NAME)

        local applied = StorageSyncService:ApplyRemoteValue("modvar", ModuleUUID, "dribblespec_sync_modvar", 1)

        D.expect(applied).toBe(false)
        D.expect(ReadStoreFileContent(DEFAULT_FILE_NAME)).toBe(defaultBefore)
    end)
end)
