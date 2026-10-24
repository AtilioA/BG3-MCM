-- Covers the receiver's own sync flags for remote Store values: a variable registered without sync toward this context keeps its local value.
-- Ext.IO cannot delete files; tests clear their keys so the fixture files hold no values afterwards.

local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")

-- Both contexts share disk, but each JSON handler saves its own complete in-memory copy.
local CONTEXT = Ext.IsServer() and "server" or "client"
local TEST_FILE_NAME = "mcm_dribblespec_sync_local_only_" .. CONTEXT .. ".json"

--- Parsed content of a Store file, or an empty table when it is missing or empty.
---@param fileName string
---@return table<string, StorageValue> data
local function ReadStoreFile(fileName)
    local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    local content = Ext.IO.LoadFile(string.format("%s/Profiles/Default/%s/%s", directory, directory, fileName))
    if not content or content == "" then
        return {}
    end
    return Ext.Json.Parse(content)
end

--- Deliver a remote value as this context receives it: a client write on the server, the store bootstrap on the client.
---@param varName string
---@param value StorageValue
local function ReceiveRemoteValue(varName, value)
    if Ext.IsServer() then
        StorageSyncService:HandleClientSet({
            storageType = "json",
            moduleUUID = ModuleUUID,
            varName = varName,
            value = value,
            storageConfig = { SyncToClient = false },
        }, -1)
    else
        StorageSyncService:HandleBootstrapPayload({ stores = { json = { [ModuleUUID] = { [varName] = value } } } })
    end
end

D.describe("StorageSync local-only", { tags = { "storage-sync", "store", "unit", "destructive" } }, function()
    D.test("TestRemoteValueDoesNotOverwriteLocalOnlyVariable", function()
        local varName = "dribblespec_sync_local_only_" .. CONTEXT
        D.expect(MCM.Store.RegisterVar(varName, {
            storageConfig = { fileName = TEST_FILE_NAME, SyncToClient = false, SyncToServer = false },
        })).toBe(true)
        MCM.Store.Set(varName, "local-value")

        ReceiveRemoteValue(varName, "remote-value")
        local fileValue = ReadStoreFile(TEST_FILE_NAME)[varName]
        local storedValue = MCM.Store.Get(varName)

        MCM.Store.Set(varName, nil)

        D.expect(fileValue).toBe("local-value")
        D.expect(storedValue).toBe("local-value")
    end)

    D.test("TestRemoteValueReachesVariableSyncedTowardReceiver", function()
        local varName = "dribblespec_sync_toward_receiver_" .. CONTEXT
        D.expect(MCM.Store.RegisterVar(varName, {
            storageConfig = { fileName = TEST_FILE_NAME, SyncToClient = true, SyncToServer = true },
        })).toBe(true)
        MCM.Store.Set(varName, "local-value")

        ReceiveRemoteValue(varName, "remote-value")
        local fileValue = ReadStoreFile(TEST_FILE_NAME)[varName]

        MCM.Store.Set(varName, nil)

        D.expect(fileValue).toBe("remote-value")
    end)
end)
