-- Concrete implementation of IStorageAdapter for ScriptExtender's ModVars.
-- Supports full SE parameter compatibility and automatic nested table dirty/sync.
-- NOTE: Actual value access is deferred until SessionLoaded event.

local IStorageAdapter = require("Shared/DynamicSettings/Adapters/IStorageAdapter")

---@class ModVarAdapter : IStorageAdapter
local ModVarAdapter = {}
setmetatable(ModVarAdapter, { __index = IStorageAdapter })
ModVarAdapter.__index = ModVarAdapter

-- Track registered variables per module to avoid duplicate registrations
-- Structure: _registered[moduleUUID][varName] = true
ModVarAdapter._registered = {}

-- Track if SessionLoaded has fired
ModVarAdapter._sessionLoaded = false

-- Queue for pending operations before SessionLoaded
-- Structure: { { type = "get"|"set", key = ..., moduleUUID = ..., storageConfig = ..., value = ..., callback = ... }, ... }
ModVarAdapter._pendingOperations = {}

-- Default SE ModVar configuration values
-- These match SE defaults but with MCM-specific overrides for Client and SyncToClient
ModVarAdapter.DEFAULTS = {
    Server = true,
    Client = true,            -- MCM override: need client visibility for UI
    WriteableOnServer = true,
    WriteableOnClient = true, -- MCM override: need client writeability for UI
    Persistent = true,        -- Save-aware by default
    SyncToClient = true,      -- MCM override: sync settings to client UI
    SyncToServer = false,
    SyncOnTick = true,
    SyncOnWrite = false,
    DontCache = false
}

--- Returns true when running on client while in main menu.
--- Net sends are invalid in this state because there is no host to receive them.
---@return boolean
local function isClientMainMenu()
    if not Ext.IsClient() then
        return false
    end

    if MCMProxy and MCMProxy.IsMainMenu then
        local ok, isMenu = pcall(MCMProxy.IsMainMenu)
        if ok then
            return isMenu == true
        end
    end

    local ok, state = pcall(Ext.Utils.GetGameState)
    if ok and Ext.Enums and Ext.Enums.ClientGameState then
        return state == Ext.Enums.ClientGameState["Menu"]
    end

    return false
end

-- Subscribe to SessionLoaded to process pending operations
Ext.Events.SessionLoaded:Subscribe(function()
    ModVarAdapter._sessionLoaded = true
    MCMDebug(1, "ModVarAdapter: SessionLoaded fired, processing " .. #ModVarAdapter._pendingOperations .. " pending operations")

    -- Process all pending operations.
    -- REVIEW? maybe use ReactiveX for this?
    for _, op in ipairs(ModVarAdapter._pendingOperations) do
        if op.type == "get" then
            local value = ModVarAdapter:_doGetValue(op.key, op.moduleUUID, op.storageConfig)
            if op.callback then
                op.callback(value)
            end
        elseif op.type == "set" then
            ModVarAdapter:_doSetValue(op.key, op.value, op.moduleUUID, op.storageConfig)
        end
    end

    -- Clear the queue
    ModVarAdapter._pendingOperations = {}
end)

--- Ensure a ModVar is registered with SE if not already registered.
--- Uses exact SE parameter names for compatibility.
---@param varName string The variable name to register
---@param moduleUUID string The module UUID
---@param storageConfig? table Optional SE configuration parameters
---@param skipBroadcast? boolean Internal use to prevent loops
function ModVarAdapter:EnsureRegistered(varName, moduleUUID, storageConfig, skipBroadcast)
    -- Initialize tracking for this module if needed
    if not self._registered[moduleUUID] then
        self._registered[moduleUUID] = {}
    end

    -- Skip if already registered
    if self._registered[moduleUUID][varName] then
        return
    end

    -- Merge user config with defaults using IStorageAdapter logic
    local config = self:ResolveConfig(storageConfig)

    -- Register with SE
    Ext.Vars.RegisterModVariable(moduleUUID, varName, config)
    self._registered[moduleUUID][varName] = true

    MCMDebug(2, string.format("ModVarAdapter: Registered '%s' for module %s with config: %s",
        varName, moduleUUID, Ext.Json.Stringify(config)))

    -- Broadcast registration to other contexts
    if not skipBroadcast and NetChannels and NetChannels.MCM_ENSURE_MODVAR_REGISTERED then
        local payload = {
            varName = varName,
            moduleUUID = moduleUUID,
            storageConfig = storageConfig
        }
        if Ext.IsServer() then
            NetChannels.MCM_ENSURE_MODVAR_REGISTERED:Broadcast(payload)
        elseif isClientMainMenu() then
            MCMDebug(3,
                string.format("ModVarAdapter: Skipping server registration relay for '%s' while in main menu", varName))
        else
            NetChannels.MCM_ENSURE_MODVAR_REGISTERED:SendToServer(payload)
        end
    end
end

--- Internal: Actually perform the GetValue operation (assumes SessionLoaded has fired)
---@param key string The key to read
---@param moduleUUID string The UUID of the module
---@param storageConfig? table Optional SE configuration parameters
---@return any value The raw Lua value or nil if not set
function ModVarAdapter:_doGetValue(key, moduleUUID, storageConfig)
    -- Ensure the variable is registered before reading to avoid SE indexing errors
    self:EnsureRegistered(key, moduleUUID, storageConfig)

    local vars = Ext.Vars.GetModVariables(moduleUUID)
    if not vars then
        return nil
    end
    local v = vars[key]
    -- SE returns nil if unset, or the stored Lua value (boolean/number/string/table)
    return v
end

--- Read a ModVar for this moduleUUID and key. Returns raw Lua value or nil.
--- NOTE: If called before SessionLoaded, returns nil immediately and the actual
--- value will be available via callback if provided.
---@param key string The key to read
---@param moduleUUID string The UUID of the module
---@param storageConfig? table Optional SE configuration parameters
---@param callback? function Optional callback(value) called when value is actually retrieved
---@return any value The raw Lua value or nil if not set (may be nil if before SessionLoaded)
function ModVarAdapter:GetValue(key, moduleUUID, storageConfig, callback)
    -- If SessionLoaded hasn't fired yet, queue the operation and return nil
    if not self._sessionLoaded then
        MCMDebug(2, string.format("ModVarAdapter:GetValue('%s') called before SessionLoaded, queuing operation", key))
        table.insert(self._pendingOperations, {
            type = "get",
            key = key,
            moduleUUID = moduleUUID,
            storageConfig = storageConfig,
            callback = callback
        })
        return nil
    end

    -- SessionLoaded has fired, execute immediately
    return self:_doGetValue(key, moduleUUID, storageConfig)
end

--- Internal: Actually perform the SetValue operation (assumes SessionLoaded has fired)
---@param key string The key to write
---@param value any The value to write (nil to delete)
---@param moduleUUID string The UUID of the module
---@param storageConfig? table Optional SE configuration parameters
function ModVarAdapter:_doSetValue(key, value, moduleUUID, storageConfig)
    -- FIXME: not persisting
    -- Ensure the variable is registered before writing
    self:EnsureRegistered(key, moduleUUID, storageConfig)

    local ok, err = pcall(function()
        local vars = Ext.Vars.GetModVariables(moduleUUID)
        if not vars then
            MCMWarn(0, "ModVarAdapter:SetValue() - GetModVariables returned nil for " .. moduleUUID)
            return
        end

        -- Write the value
        vars[key] = value

        -- Always dirty and sync to handle nested table changes
        -- SE does not auto-detect nested table modifications, so we must explicitly dirty
        Ext.Vars.DirtyModVariables(moduleUUID)

        -- Immediate sync if configured
        local syncOnWrite = storageConfig and storageConfig.SyncOnWrite
        if syncOnWrite then
            Ext.Vars.SyncModVariables(moduleUUID)
        end
        -- Otherwise sync happens on next tick (SyncOnTick = true by default)
        MCMDebug(1, "ModVarAdapter:SetValue() - Set value for '" .. key .. "' to '" .. tostring(value) .. "' for module " .. moduleUUID)
    end)

    if not ok then
        MCMWarn(0, "ModVarAdapter:SetValue() failed: " .. tostring(err))
    end
end

--- Write a ModVar for (key, value, moduleUUID). If value==nil, remove that variable.
--- Automatically handles nested table dirty/sync.
--- NOTE: If called before SessionLoaded, the operation is queued and executed after SessionLoaded.
---@param key string The key to write
---@param value any The value to write (nil to delete)
---@param moduleUUID string The UUID of the module
---@param storageConfig? table Optional SE configuration parameters
function ModVarAdapter:SetValue(key, value, moduleUUID, storageConfig)
    -- If SessionLoaded hasn't fired yet, queue the operation
    if not self._sessionLoaded then
        MCMDebug(2, string.format("ModVarAdapter:SetValue('%s') called before SessionLoaded, queuing operation", key))
        table.insert(self._pendingOperations, {
            type = "set",
            key = key,
            value = value,
            moduleUUID = moduleUUID,
            storageConfig = storageConfig
        })
        return
    end

    -- SessionLoaded has fired, execute immediately
    self:_doSetValue(key, value, moduleUUID, storageConfig)
end

return ModVarAdapter
