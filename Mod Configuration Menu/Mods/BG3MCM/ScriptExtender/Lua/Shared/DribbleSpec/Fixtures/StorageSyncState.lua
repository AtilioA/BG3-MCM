--- Create a fixture that isolates mutable storage-sync service and adapter state.
---@param storageSyncService StorageSyncService
---@param jsonAdapter JsonStorageManager
---@param settingsService SettingsService
---@return table fixture
return function(storageSyncService, jsonAdapter, settingsService)
    local previousState
    local filesToRestore = {}
    local fixture = {}

    --- Replace test-owned state while retaining the live tables for restoration.
    ---@return nil
    function fixture:Isolate()
        filesToRestore = {}
        previousState = {
            cache = storageSyncService._cache,
            applyingRemote = storageSyncService._applyingRemote,
            testMode = storageSyncService._testMode,
            jsonCache = jsonAdapter._cache,
            jsonFileNames = jsonAdapter._fileNames,
            settingsSchema = settingsService.schema,
            settingsVarToStorageType = settingsService.varToStorageType,
        }

        storageSyncService._cache = {}
        storageSyncService._applyingRemote = false
        storageSyncService._testMode = false
        jsonAdapter._cache = {}
        jsonAdapter._fileNames = {}
        settingsService.schema = {}
        settingsService.varToStorageType = {}
    end

    --- Remember bytes before a test can write to this fixture or routing destination.
    ---@param path string Script Extender-relative file path
    ---@return nil
    function fixture:RememberFile(path)
        if not filesToRestore[path] then
            filesToRestore[path] = { content = Ext.IO.LoadFile(path) }
        end
    end

    --- Restore files and live state, reporting file failures after state cleanup.
    ---@return nil
    function fixture:Restore()
        if not previousState then
            return
        end

        local failures = {}
        for path, snapshot in pairs(filesToRestore) do
            if Ext.IO.LoadFile(path) ~= snapshot.content then
                local expectedContent = snapshot.content or ""
                local restored = Ext.IO.SaveFile(path, expectedContent)
                if not restored or Ext.IO.LoadFile(path) ~= expectedContent then
                    table.insert(failures, path)
                end
            end
        end

        storageSyncService._cache = previousState.cache
        storageSyncService._applyingRemote = previousState.applyingRemote
        storageSyncService._testMode = previousState.testMode
        jsonAdapter._cache = previousState.jsonCache
        jsonAdapter._fileNames = previousState.jsonFileNames
        settingsService.schema = previousState.settingsSchema
        settingsService.varToStorageType = previousState.settingsVarToStorageType
        previousState = nil
        filesToRestore = {}
        if #failures > 0 then
            error("Failed to restore DribbleSpec Store fixture files: " .. table.concat(failures, ", "))
        end
    end

    return fixture
end
