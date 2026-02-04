-- Concrete implementation of IStorageAdapter for ScriptExtender's ModVars.
-- Supports full SE parameter compatibility and automatic nested table dirty/sync.

local IStorageAdapter = require("Shared/DynamicSettings/Adapters/IStorageAdapter")

---@class ModVarAdapter : IStorageAdapter
local ModVarAdapter = {}
setmetatable(ModVarAdapter, { __index = IStorageAdapter })
ModVarAdapter.__index = ModVarAdapter

-- Track registered variables per module to avoid duplicate registrations
-- Structure: _registered[moduleUUID][varName] = true
ModVarAdapter._registered = {}

-- Default SE ModVar configuration values
-- These match SE defaults but with MCM-specific overrides for Client and SyncToClient
ModVarAdapter.DEFAULTS = {
    Server = true,
    Client = true, -- MCM override: need client visibility for UI
    WriteableOnServer = true,
    WriteableOnClient = false,
    Persistent = true,   -- Save-aware by default
    SyncToClient = true, -- MCM override: sync settings to client UI
    SyncToServer = false,
    SyncOnTick = true,
    SyncOnWrite = false,
    DontCache = false
}

--- Ensure a ModVar is registered with SE if not already registered.
--- Uses exact SE parameter names for compatibility.
---@param varName string The variable name to register
---@param moduleUUID string The module UUID
---@param storageConfig? table Optional SE configuration parameters
function ModVarAdapter:EnsureRegistered(varName, moduleUUID, storageConfig)
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
end

--- Read a ModVar for this moduleUUID and key. Returns raw Lua value or nil.
---@param key string The key to read
---@param moduleUUID string The UUID of the module
---@return any value The raw Lua value or nil if not set
function ModVarAdapter:GetValue(key, moduleUUID)
    local vars = Ext.Vars.GetModVariables(moduleUUID)
    if not vars then
        return nil
    end
    local v = vars[key]
    -- SE returns nil if unset, or the stored Lua value (boolean/number/string/table)
    return v
end

--- Write a ModVar for (key, value, moduleUUID). If value==nil, remove that variable.
--- Automatically handles nested table dirty/sync.
---@param key string The key to write
---@param value any The value to write (nil to delete)
---@param moduleUUID string The UUID of the module
---@param storageConfig? table Optional SE configuration parameters
function ModVarAdapter:SetValue(key, value, moduleUUID, storageConfig)
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
    end)

    if not ok then
        MCMWarn(0, "ModVarAdapter:SetValue() failed: " .. tostring(err))
    end
end

return ModVarAdapter
