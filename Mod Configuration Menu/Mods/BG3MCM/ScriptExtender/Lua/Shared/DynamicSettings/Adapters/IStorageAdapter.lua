-- Defines the interface that every storage adapter must implement.

---@class IStorageAdapter
local IStorageAdapter = {}
IStorageAdapter.__index = IStorageAdapter

-- Default configuration (override in subclasses)
IStorageAdapter.DEFAULTS = {}

--- Merge provided configuration with adapter defaults.
---@param providedConfig? table User-provided configuration
---@return table config The complete configuration with defaults applied
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

--- Read the raw Lua value (boolean/number/string/table/etc.) for (moduleUUID, key).
--- Returns nil if the variable is not set.
---@param key string The key to read
---@param moduleUUID string The UUID of the module
---@param storageConfig? table Optional storage-specific configuration (e.g., SE ModVar parameters)
---@return any value The raw Lua value or nil if not set
function IStorageAdapter:GetValue(key, moduleUUID, storageConfig)
    MCMError(0, "IStorageAdapter:GetValue() not implemented")
end

--- Write the raw Lua value (boolean/number/string/table/etc.) for (moduleUUID, key).
--- If value == nil, nullify the variable.
---@param key string The key to write
---@param value any The value to write (nil to delete)
---@param moduleUUID string The UUID of the module
---@param storageConfig? table Optional storage-specific configuration (e.g., SE ModVar parameters)
function IStorageAdapter:SetValue(key, value, moduleUUID, storageConfig)
    MCMError(0, "IStorageAdapter:SetValue() not implemented")
end

return IStorageAdapter
