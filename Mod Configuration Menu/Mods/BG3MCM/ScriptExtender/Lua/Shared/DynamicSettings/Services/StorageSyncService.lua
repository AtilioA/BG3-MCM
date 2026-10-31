---@class StorageSyncPayload
---@field storageType string
---@field moduleUUID string
---@field varName string
---@field value StorageValue
---@field storageConfig? StorageConfig

---@class StorageSyncService
---@field private _cache table<string, table<string, table<string, StorageValue>>> cache[storageType][moduleUUID][varName]
---@field private _adapters table<string, IStorageAdapter>
---@field private _applyingRemote boolean
StorageSyncService = {
    _cache = {},
    _adapters = {},
    _applyingRemote = false,
}

---@param storageType string
---@return string
local function normalizeStorageType(storageType)
    return string.lower(storageType or "")
end

---@param payload unknown
---@return table|nil
local function parsePayload(payload)
    if type(payload) == "table" then
        return payload
    end

    local ok, parsed = pcall(Ext.Json.Parse, payload)
    if ok and type(parsed) == "table" then
        return parsed
    end

    return nil
end

---@return integer[]
local function getConnectedUserIDs()
    local result = {}
    local seen = {}
    for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ClientControl")) do
        local userID = entity.UserReservedFor and entity.UserReservedFor.UserID
        if type(userID) == "number" and not seen[userID] then
            table.insert(result, userID)
            seen[userID] = true
        end
    end

    return result
end

---@param stores table<string, table<string, table<string, StorageValue>>>
---@return table<string, table<string, table<string, StorageValue>>>
local function deepCopyStores(stores)
    local copy = {}
    for storageType, mods in pairs(stores or {}) do
        copy[storageType] = {}
        for moduleUUID, vars in pairs(mods or {}) do
            copy[storageType][moduleUUID] = {}
            for varName, value in pairs(vars or {}) do
                copy[storageType][moduleUUID][varName] = table.deepcopy(value)
            end
        end
    end

    return copy
end

---@param payload StorageSyncPayload
---@param excludeUserID? integer
function StorageSyncService:_syncToClients(payload, excludeUserID)
    for _, userID in ipairs(getConnectedUserIDs()) do
        if not excludeUserID or userID ~= excludeUserID then
            NetChannels.MCM_SERVER_SYNC_STORE_VALUE:SendToClient(payload, userID)
        end
    end
end

---@param storageType string
---@param adapter IStorageAdapter
function StorageSyncService:RegisterStorageAdapter(storageType, adapter)
    self._adapters[normalizeStorageType(storageType)] = adapter
end

---@param storageType string
---@return IStorageAdapter|nil
function StorageSyncService:GetRegisteredStorageAdapter(storageType)
    local normalizedStorageType = normalizeStorageType(storageType)
    return self._adapters[normalizedStorageType]
end

---@param storageType string
---@param moduleUUID string
---@param varName string
---@param value StorageValue
function StorageSyncService:SetCachedValue(storageType, moduleUUID, varName, value)
    local normalizedStorageType = normalizeStorageType(storageType)
    self._cache[normalizedStorageType] = self._cache[normalizedStorageType] or {}
    self._cache[normalizedStorageType][moduleUUID] = self._cache[normalizedStorageType][moduleUUID] or {}

    self._cache[normalizedStorageType][moduleUUID][varName] = value
end

---@param storageType string
---@param moduleUUID string
---@param varName string
---@return StorageValue
function StorageSyncService:GetCachedValue(storageType, moduleUUID, varName)
    local normalizedStorageType = normalizeStorageType(storageType)
    local byStorage = self._cache[normalizedStorageType]
    local byMod = byStorage and byStorage[moduleUUID]
    if byMod then
        return byMod[varName]
    end

    return nil
end

function StorageSyncService:BeginRemoteApply()
    self._applyingRemote = true
end

function StorageSyncService:EndRemoteApply()
    self._applyingRemote = false
end

---@param config StorageConfig|nil
---@return boolean
function StorageSyncService:CanBroadcastLocalWrite(config)
    if self._applyingRemote then
        return false
    end

    return config ~= nil and config.SyncToClient == true
end

---@param config StorageConfig|nil
---@return boolean
function StorageSyncService:CanClientSendToServer(config)
    if self._applyingRemote then
        return false
    end

    return config ~= nil and config.SyncToServer == true
end

---@param storageType string
---@param moduleUUID string
---@param varName string
---@param value StorageValue
---@param config StorageConfig|nil
function StorageSyncService:OnLocalSet(storageType, moduleUUID, varName, value, config)
    self:SetCachedValue(storageType, moduleUUID, varName, value)

    local payload = {
        storageType = normalizeStorageType(storageType),
        moduleUUID = moduleUUID,
        varName = varName,
        value = value,
        storageConfig = config,
    }

    -- Mutation-equivalent on server: forcing true takes the server path the server already takes; client tests cover the false case
    if Ext.IsServer() then
        if self:CanBroadcastLocalWrite(config) then
            self:_syncToClients(payload, nil)
        end
        return
    end

    -- Mutation-equivalent on server: unreachable there, as the server returns above; client tests cover it
    if MCMUtils.IsClientMainMenu() then
        return
    end

    -- Mutation-equivalent on server: unreachable there, as the server returns above; client tests cover it
    if self:CanClientSendToServer(config) then
        NetChannels.MCM_CLIENT_SET_STORE_VALUE:SendToServer(payload)
    end
end

---@param storageType string
---@param moduleUUID string
---@param varName string
---@param value StorageValue
---@return boolean
function StorageSyncService:ApplyRemoteValue(storageType, moduleUUID, varName, value)
    local adapter = self:GetRegisteredStorageAdapter(storageType)
    if not adapter then
        return false
    end

    -- An unregistered variable has no file on record, so writing would put it in the default file; the payload does not choose placement.
    if not adapter:IsRegistered(varName, moduleUUID) then
        MCMWarn(0, "StorageSyncService: ignored synced %s value '%s' for mod %s: the variable is not registered",
            normalizeStorageType(storageType), varName, moduleUUID)
        return false
    end

    -- The receiver's own registration decides sync; senders (e.g. the bootstrap) may include values that are not synced toward this context.
    local registeredConfig = adapter:ResolveConfig(SettingsService.GetStorageConfig(moduleUUID, varName))
    local syncsHere = registeredConfig.SyncToClient
    -- Mutation-equivalent on server: forcing true takes the server path the server already takes; client tests cover the false case
    if Ext.IsServer() then
        syncsHere = registeredConfig.SyncToServer
    end
    if syncsHere ~= true then
        MCMDebug(1, "StorageSyncService: ignored synced %s value '%s' for mod %s: the variable does not sync to this context",
            normalizeStorageType(storageType), varName, moduleUUID)
        return false
    end

    self:BeginRemoteApply()
    -- The remote-apply flag stops OnLocalSet from sending the value back
    local saved = adapter:SetValue(varName, value, moduleUUID)
    self:EndRemoteApply()
    -- A refused write (e.g. an unreadable JSON file) is not cached: the adapter caches only saved values
    return saved ~= false
end

---@param data unknown
---@param userID integer
---@return table
function StorageSyncService:HandleClientSet(data, userID)
    local payload = parsePayload(data)
    if not payload then
        return { success = false, error = "Invalid payload" }
    end

    local storageType = normalizeStorageType(payload.storageType)
    local moduleUUID = payload.moduleUUID
    local varName = payload.varName

    if storageType == "" or not moduleUUID or not varName then
        return { success = false, error = "Missing storageType/moduleUUID/varName" }
    end

    local adapter = self:GetRegisteredStorageAdapter(storageType)
    if not adapter then
        return { success = false, error = "Unknown storageType" }
    end

    -- The server's own registration decides the rebroadcast; a client cannot widen it through its payload
    local resolvedConfig = adapter:ResolveConfig(SettingsService.GetStorageConfig(moduleUUID, varName))

    -- last-write-wins: server accepts latest arriving write
    local didApply = self:ApplyRemoteValue(storageType, moduleUUID, varName, payload.value)
    if not didApply then
        return { success = false, error = "Failed to apply value" }
    end

    if resolvedConfig.SyncToClient == true then
        local syncPayload = {
            storageType = storageType,
            moduleUUID = moduleUUID,
            varName = varName,
            value = payload.value,
            storageConfig = resolvedConfig,
        }
        self:_syncToClients(syncPayload, userID)
    end

    return { success = true }
end

---@param data unknown
---@param userID integer
---@return table
function StorageSyncService:HandleBootstrapRequest(data, userID)
    self:SendBootstrapToUser(userID)
    return { success = true }
end

---@return table
function StorageSyncService:BuildBootstrapPayload()
    return { stores = deepCopyStores(self._cache) }
end

---@return table
function StorageSyncService:CollectAllPersistedState()
    local payload = self:BuildBootstrapPayload()
    local stores = payload.stores

    -- Backfill from persistence via all registered adapters.
    for storageType, adapter in pairs(self._adapters) do
        stores[storageType] = stores[storageType] or {}
        table.mergeDefaults(stores[storageType], adapter:GetAllValues())
    end

    return payload
end

---@param userID integer
function StorageSyncService:SendBootstrapToUser(userID)
    local payload = self:CollectAllPersistedState()
    ChunkedNet.SendJSONToUser(userID, NetChannels.MCM_SERVER_SEND_STORE_BOOTSTRAP, payload)
end

---@param data unknown
function StorageSyncService:HandleBootstrapPayload(data)
    local payload = parsePayload(data)
    if not payload then
        return
    end

    local stores = payload.stores or {}
    for storageType, mods in pairs(stores) do
        for moduleUUID, vars in pairs(mods or {}) do
            for varName, value in pairs(vars or {}) do
                self:ApplyRemoteValue(storageType, moduleUUID, varName, value)
            end
        end
    end
end

---@param data unknown
function StorageSyncService:HandleServerSyncPayload(data)
    local payload = parsePayload(data)
    if not payload then
        return
    end

    self:ApplyRemoteValue(payload.storageType, payload.moduleUUID, payload.varName, payload.value)
end

return StorageSyncService
