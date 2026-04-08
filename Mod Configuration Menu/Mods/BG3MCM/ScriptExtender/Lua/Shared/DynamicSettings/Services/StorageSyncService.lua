---@class StorageSyncPayload
---@field storageType string
---@field moduleUUID string
---@field varName string
---@field value any
---@field originUserID? integer
---@field storageConfig? table

---@class StorageSyncService
---@field private _cache table<string, table<string, table<string, any>>> cache[storageType][moduleUUID][varName]
---@field private _adapters table<string, table>
---@field private _applyingRemote boolean
---@field private _testMode boolean
StorageSyncService = {
    _cache = {},
    _adapters = {},
    _applyingRemote = false,
    _testMode = false,
}

---@param storageType string
---@return string
local function normalizeStorageType(storageType)
    return string.lower(storageType or "")
end

---@param payload any
---@return table|nil
local function parsePayload(payload)
    if type(payload) == "table" then
        return payload
    end

    if type(payload) == "string" then
        local ok, parsed = pcall(Ext.Json.Parse, payload)
        if ok and type(parsed) == "table" then
            return parsed
        end
    end

    return nil
end

---@return boolean
local function isClientMainMenu()
    if not Ext.IsClient() then
        return false
    end

    if MCMProxy and MCMProxy.IsMainMenu then
        local ok, inMenu = pcall(MCMProxy.IsMainMenu)
        if ok then
            return inMenu == true
        end
    end

    local ok, state = pcall(Ext.Utils.GetGameState)
    if ok and Ext.Enums and Ext.Enums.ClientGameState then
        return state == Ext.Enums.ClientGameState["Menu"]
    end

    return false
end

---@return integer|nil
local function getLocalUserID()
    if not Ext.IsClient() then
        return nil
    end

    return _C().UserReservedFor.UserID
end

---@return integer[]
local function getConnectedUserIDs()
    local result = {}
    local seen = {}
    local entities = Ext.Entity.GetAllEntitiesWithComponent("ClientControl")
    if not entities then
        return result
    end

    for _, entity in pairs(entities) do
        local userID = entity and entity.UserReservedFor and entity.UserReservedFor.UserID
        if type(userID) == "number" and not seen[userID] then
            table.insert(result, userID)
            seen[userID] = true
        end
    end

    return result
end

---@param stores table<string, table<string, table<string, any>>>
---@return table<string, table<string, table<string, any>>>
local function deepCopyStores(stores)
    local copy = {}
    for storageType, mods in pairs(stores or {}) do
        copy[storageType] = {}
        for moduleUUID, vars in pairs(mods or {}) do
            copy[storageType][moduleUUID] = {}
            for varName, value in pairs(vars or {}) do
                copy[storageType][moduleUUID][varName] = value
            end
        end
    end

    return copy
end

---@param payload StorageSyncPayload
---@param excludeUserID? integer
function StorageSyncService:_syncToClients(payload, excludeUserID)
    if not Ext.IsServer() or self._testMode then
        return
    end

    for _, userID in ipairs(getConnectedUserIDs()) do
        if not excludeUserID or userID ~= excludeUserID then
            NetChannels.MCM_SERVER_SYNC_STORE_VALUE:SendToClient(payload, userID)
        end
    end
end

---@param storageType string
---@param adapter table
function StorageSyncService:RegisterStorageAdapter(storageType, adapter)
    if type(storageType) ~= "string" or storageType == "" then
        return
    end

    self._adapters[normalizeStorageType(storageType)] = adapter
end

---@param storageType string
---@return table|nil
function StorageSyncService:GetRegisteredStorageAdapter(storageType)
    local normalizedStorageType = normalizeStorageType(storageType)
    return self._adapters[normalizedStorageType]
end

---@param storageType string
---@param moduleUUID string
---@param varName string
---@param value any
function StorageSyncService:SetCachedValue(storageType, moduleUUID, varName, value)
    local normalizedStorageType = normalizeStorageType(storageType)
    self._cache[normalizedStorageType] = self._cache[normalizedStorageType] or {}
    self._cache[normalizedStorageType][moduleUUID] = self._cache[normalizedStorageType][moduleUUID] or {}

    if value == nil then
        self._cache[normalizedStorageType][moduleUUID][varName] = nil
    else
        self._cache[normalizedStorageType][moduleUUID][varName] = value
    end
end

---@param storageType string
---@param moduleUUID string
---@param varName string
---@return any
function StorageSyncService:GetCachedValue(storageType, moduleUUID, varName)
    local normalizedStorageType = normalizeStorageType(storageType)
    local byStorage = self._cache[normalizedStorageType]
    local byMod = byStorage and byStorage[moduleUUID]
    return byMod and byMod[varName] or nil
end

function StorageSyncService:BeginRemoteApply()
    self._applyingRemote = true
end

function StorageSyncService:EndRemoteApply()
    self._applyingRemote = false
end

---@param config table|nil
---@return boolean
function StorageSyncService:CanBroadcastLocalWrite(config)
    if self._applyingRemote then
        return false
    end

    return config and config.SyncToClient == true
end

---@param config table|nil
---@return boolean
function StorageSyncService:CanClientSendToServer(config)
    if self._applyingRemote then
        return false
    end

    return config and config.SyncToServer == true
end

---@param originUserID integer|nil
---@param localUserID integer|nil
---@return boolean
function StorageSyncService:ShouldApplyOnClient(originUserID, localUserID)
    if originUserID == nil then
        return true
    end

    if localUserID == nil then
        return true
    end

    return originUserID ~= localUserID
end

---@param storageType string
---@param moduleUUID string
---@param varName string
function StorageSyncService:EnsureDiscovered(storageType, moduleUUID, varName)
    if SettingsService and SettingsService.RegisterDiscoveredVariable then
        SettingsService.RegisterDiscoveredVariable(moduleUUID, varName, storageType)
    end
end

---@param storageType string
---@param moduleUUID string
---@param varName string
---@param value any
---@param config table|nil
function StorageSyncService:OnLocalSet(storageType, moduleUUID, varName, value, config)
    self:SetCachedValue(storageType, moduleUUID, varName, value)
    self:EnsureDiscovered(storageType, moduleUUID, varName)

    if self._applyingRemote then
        return
    end

    local payload = {
        storageType = normalizeStorageType(storageType),
        moduleUUID = moduleUUID,
        varName = varName,
        value = value,
        storageConfig = config,
    }

    if Ext.IsServer() then
        if self:CanBroadcastLocalWrite(config) then
            self:_syncToClients(payload, nil)
        end
        return
    end

    if not Ext.IsClient() then
        return
    end

    if isClientMainMenu() then
        return
    end

    if self:CanClientSendToServer(config) then
        NetChannels.MCM_CLIENT_SET_STORE_VALUE:SendToServer(payload)
    end
end

---@param storageType string
---@param moduleUUID string
---@param varName string
---@param value any
---@param storageConfig table|nil
---@return boolean
function StorageSyncService:ApplyRemoteValue(storageType, moduleUUID, varName, value, storageConfig)
    local adapter = self:GetRegisteredStorageAdapter(storageType)
    if not adapter or not adapter.SetValue then
        return false
    end

    self:BeginRemoteApply()
    adapter:SetValue(varName, value, moduleUUID, {
        SyncToClient = false,
        SyncToServer = false,
        Server = true,
        Client = true,
    })
    self:EndRemoteApply()

    self:SetCachedValue(storageType, moduleUUID, varName, value)
    self:EnsureDiscovered(storageType, moduleUUID, varName)
    return true
end

---@param data any
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

    local resolvedConfig = adapter.ResolveConfig and adapter:ResolveConfig(payload.storageConfig) or payload.storageConfig or {}

    -- last-write-wins: server accepts latest arriving write
    local didApply = self:ApplyRemoteValue(storageType, moduleUUID, varName, payload.value, resolvedConfig)
    if not didApply then
        return { success = false, error = "Failed to apply value" }
    end

    if resolvedConfig.SyncToClient == true then
        local syncPayload = {
            storageType = storageType,
            moduleUUID = moduleUUID,
            varName = varName,
            value = payload.value,
            originUserID = userID,
            storageConfig = resolvedConfig,
        }
        self:_syncToClients(syncPayload, userID)
    end

    return { success = true }
end

---@param data any
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
        if adapter and adapter.GetAllValues then
            local all = adapter:GetAllValues()
            if all then
                stores[storageType] = stores[storageType] or {}
                table.mergeDefaults(stores[storageType], all)
            end
        end
    end

    return payload
end

---@param userID integer
function StorageSyncService:SendBootstrapToUser(userID)
    if self._testMode then
        return
    end

    local payload = self:CollectAllPersistedState()
    ChunkedNet.SendJSONToUser(userID, NetChannels.MCM_SERVER_SEND_STORE_BOOTSTRAP, payload)
end

---@param data any
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

---@param data any
function StorageSyncService:HandleServerSyncPayload(data)
    local payload = parsePayload(data)
    if not payload then
        return
    end

    local localUserID = getLocalUserID()
    if not self:ShouldApplyOnClient(payload.originUserID, localUserID) then
        return
    end

    self:ApplyRemoteValue(payload.storageType, payload.moduleUUID, payload.varName, payload.value, payload.storageConfig)
end

---@param enabled boolean
function StorageSyncService:SetTestMode(enabled)
    self._testMode = enabled == true
end

function StorageSyncService:ResetForTests()
    self._cache = {}
    self._applyingRemote = false
    self._testMode = false
end

return StorageSyncService
