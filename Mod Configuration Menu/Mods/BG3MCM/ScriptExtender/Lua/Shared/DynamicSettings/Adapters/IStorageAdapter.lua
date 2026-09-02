-- Defines the interface that every storage adapter must implement.

---@class IStorageAdapter
local IStorageAdapter = {}
IStorageAdapter.__index = IStorageAdapter

-- Default configuration (override in subclasses)
IStorageAdapter.DEFAULTS = {}

--- Merge provided configuration with adapter defaults.
---@param providedConfig? StorageConfig User-provided configuration
---@return StorageConfig config The complete configuration with defaults applied
function IStorageAdapter:ResolveConfig(providedConfig)
    local config = {}

    -- Apply defaults first
    for k, v in pairs(self.DEFAULTS) do
        config[k] = v
    end

    -- Override with user config
    if providedConfig then
        for k, v in pairs(providedConfig) do
            config[k] = v
        end
    end

    return config
end

--- Ensure the underlying storage prototype is registered for (moduleUUID, key).
--- MUST be safe to call at bootstrap (before SessionLoaded), since some backends (e.g. SE ModVariables) require registration before the savegame restores values.
--- Default implementation is a no-op for backends that need no registration (e.g. JSON).
---@param key string The key/variable name
---@param moduleUUID string The UUID of the module
---@param storageConfig? StorageConfig Optional storage-specific configuration (e.g., SE ModVar parameters)
function IStorageAdapter:EnsureRegistered(key, moduleUUID, storageConfig)
    -- No registration required by default.
end

--- Run `fn` once this backend can serve real values. Example: "wait for the savegame before restoring values" timing lives here.
---@param fn fun() Callback to run when the adapter is ready
function IStorageAdapter:RunWhenReady(fn)
    fn()
end

--- Read the raw Lua value (boolean/number/string/table/etc.) for (moduleUUID, key).
--- Returns nil if the variable is not set.
---@param key string The key to read
---@param moduleUUID string The UUID of the module
---@param storageConfig? StorageConfig Optional storage-specific configuration (e.g., SE ModVar parameters)
---@return StorageValue value The raw Lua value or nil if not set
function IStorageAdapter:GetValue(key, moduleUUID, storageConfig)
    MCMError(0, "IStorageAdapter:GetValue() not implemented")
end

--- Write the raw Lua value (boolean/number/string/table/etc.) for (moduleUUID, key).
--- If value == nil, nullify the variable.
---@param key string The key to write
---@param value StorageValue The value to write (nil to delete)
---@param moduleUUID string The UUID of the module
---@param storageConfig? StorageConfig Optional storage-specific configuration (e.g., SE ModVar parameters)
function IStorageAdapter:SetValue(key, value, moduleUUID, storageConfig)
    MCMError(0, "IStorageAdapter:SetValue() not implemented")
end

return IStorageAdapter
