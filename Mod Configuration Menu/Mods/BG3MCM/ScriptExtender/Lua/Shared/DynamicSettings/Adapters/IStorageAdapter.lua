-- Defines the interface that every storage adapter must implement.

---@class IStorageAdapter
local IStorageAdapter = {}

--- Read the raw Lua value (boolean/number/string/table/etc.) for (moduleUUID, key).
--- Returns nil if the variable is not set.
---@param moduleUUID string The UUID of the module
---@param key string The key to read
---@return any value The raw Lua value or nil if not set
function IStorageAdapter:GetValue(moduleUUID, key)
    error("IStorageAdapter:GetValue() not implemented")
end

--- Write the raw Lua value (boolean/number/string/table/etc.) for (moduleUUID, key).
--- If value == nil, nullify the variable.
---@param moduleUUID string The UUID of the module
---@param key string The key to write
---@param value any The value to write (nil to delete)
function IStorageAdapter:SetValue(moduleUUID, key, value)
    error("IStorageAdapter:SetValue() not implemented")
end

return IStorageAdapter
