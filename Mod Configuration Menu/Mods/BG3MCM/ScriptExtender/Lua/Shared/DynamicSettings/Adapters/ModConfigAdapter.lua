-- Stub for future ScriptExtender ModConfig support. Throws until SE exposes ModConfig methods.

local IStorageAdapter = require("Shared/DynamicSettings/Adapters/IStorageAdapter")

---@class ModConfigAdapter : IStorageAdapter
local ModConfigAdapter = {}
setmetatable(ModConfigAdapter, { __index = IStorageAdapter })
ModConfigAdapter.__index = ModConfigAdapter

--- Future: replace with Ext.ModConfig.GetValue(moduleUUID, key)
---@param moduleUUID string The UUID of the module
---@param key string The key to read
---@return any value The raw Lua value or nil if not set
function ModConfigAdapter:GetValue(moduleUUID, key)
  error("ModConfigAdapter:GetValue(): ModConfig not available yet.")
end

--- Future: replace with Ext.ModConfig.SetValue(moduleUUID, key, value) and Sync
---@param moduleUUID string The UUID of the module
---@param key string The key to write
---@param value any The value to write (nil to delete)
function ModConfigAdapter:SetValue(moduleUUID, key, value)
  error("ModConfigAdapter:SetValue(): ModConfig not available yet.")
end

return ModConfigAdapter
