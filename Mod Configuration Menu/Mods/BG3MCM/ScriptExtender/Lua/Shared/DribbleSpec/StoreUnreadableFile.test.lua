-- Covers MCM.Store protection of JSON Store files that cannot be parsed (ADR 0003).
-- Each test uses its own fixture file, because MCM keeps a loaded file in memory until the next reset.
-- Both realms share disk, but each JSON handler saves its own complete in-memory copy.
local REALM = Ext.IsServer() and "server" or "client"

local UNREADABLE_CONTENT = '{"dribblespec_store_unreadable": tru'

--- Path of a file in MCM's own Store directory, as documented for storageConfig.fileName.
---@param fileName string
---@return string path
local function StoreFilePath(fileName)
    local directory = Ext.Mod.GetMod(ModuleUUID).Info.Directory
    return string.format("%s/Profiles/Default/%s/%s", directory, directory, fileName)
end

D.describe("MCM.Store unreadable file", { tags = { "store", "unit", "destructive" } }, function()
    D.test("TestStoreKeepsUnparsableFileUnchangedAfterSet", function()
        local fileName = "mcm_dribblespec_store_unreadable_set_" .. REALM .. ".json"
        local varName = "dribblespec_store_unreadable_set_" .. REALM
        Ext.IO.SaveFile(StoreFilePath(fileName), UNREADABLE_CONTENT)
        MCM.Store.RegisterVar(varName, { storageConfig = { fileName = fileName } })

        local setResult = MCM.Store.Set(varName, true)

        D.expect(setResult).toBe(false)
        D.expect(Ext.IO.LoadFile(StoreFilePath(fileName))).toBe(UNREADABLE_CONTENT)
        D.expect(MCM.Store.Get(varName)).toBeNil()
        D.expect(MCM.Store.IsWritable(varName)).toBe(false)
    end)

    D.test("TestStoreUnparsableFileDoesNotBlockOtherFiles", function()
        local unreadableFileName = "mcm_dribblespec_store_unreadable_other_" .. REALM .. ".json"
        local readableFileName = "mcm_dribblespec_store_readable_other_" .. REALM .. ".json"
        local unreadableVar = "dribblespec_store_unreadable_other_" .. REALM
        local readableVar = "dribblespec_store_readable_other_" .. REALM
        Ext.IO.SaveFile(StoreFilePath(unreadableFileName), UNREADABLE_CONTENT)
        MCM.Store.RegisterVar(unreadableVar, { storageConfig = { fileName = unreadableFileName } })
        MCM.Store.RegisterVar(readableVar, { storageConfig = { fileName = readableFileName } })
        MCM.Store.Set(unreadableVar, 1)

        local setResult = MCM.Store.Set(readableVar, 2)
        local storedValue = MCM.Store.Get(readableVar)
        local writable = MCM.Store.IsWritable(readableVar)
        MCM.Store.Set(readableVar, nil)

        D.expect(setResult).toBe(true)
        D.expect(storedValue).toBe(2)
        D.expect(writable).toBe(true)
    end)
end)
