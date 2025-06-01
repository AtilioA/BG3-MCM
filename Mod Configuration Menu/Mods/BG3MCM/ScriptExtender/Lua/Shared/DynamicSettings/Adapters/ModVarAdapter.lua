-- Concrete implementation of IStorageAdapter for ScriptExtender's ModVars.

local IStorageAdapter = require("Shared/DynamicSettings/Adapters/IStorageAdapter")

---@class ModVarAdapter : IStorageAdapter
local ModVarAdapter = {}
setmetatable(ModVarAdapter, { __index = IStorageAdapter })
ModVarAdapter.__index = ModVarAdapter

--- Read a ModVar for this moduleUUID and key. Returns raw Lua value or nil.
---@param moduleUUID string The UUID of the module
---@param key string The key to read
---@return any value The raw Lua value or nil if not set
function ModVarAdapter:GetValue(moduleUUID, key)
  local vars = Ext.Vars.GetModVariables(moduleUUID)
  if not vars then
    return nil
  end
  local v = vars[key]
  -- SE returns nil if unset, or the stored Lua value (boolean/number/string/table).
  return v
end

--- Write a ModVar for (moduleUUID, key). If value==nil, remove that variable.
---@param moduleUUID string The UUID of the module
---@param key string The key to write
---@param value any The value to write (nil to delete)
function ModVarAdapter:SetValue(moduleUUID, key, value)
  local vars = Ext.Vars.GetModVariables(moduleUUID)
  if not vars then
    -- Module not loaded or has no variables table—nothing to do.
    return
  end
  if value == nil then
    vars[key] = nil
  else
    vars[key] = value
  end
  Ext.Vars.SyncModVariables(moduleUUID)
end

return ModVarAdapter
