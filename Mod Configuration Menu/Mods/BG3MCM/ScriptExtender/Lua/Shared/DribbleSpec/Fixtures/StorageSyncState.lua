--- Create a fixture that isolates mutable storage-sync service and adapter state.
---@param storageSyncService StorageSyncService
---@param jsonAdapter JsonStorageManager
---@param settingsService SettingsService
---@return table fixture
return function(storageSyncService, jsonAdapter, settingsService)
    local previousState
    local fixture = {}

    function fixture:Isolate()
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

    function fixture:Restore()
        if not previousState then
            return
        end

        storageSyncService._cache = previousState.cache
        storageSyncService._applyingRemote = previousState.applyingRemote
        storageSyncService._testMode = previousState.testMode
        jsonAdapter._cache = previousState.jsonCache
        jsonAdapter._fileNames = previousState.jsonFileNames
        settingsService.schema = previousState.settingsSchema
        settingsService.varToStorageType = previousState.settingsVarToStorageType
        previousState = nil
    end

    return fixture
end
