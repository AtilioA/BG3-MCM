-- Concrete implementation of IStorageAdapter for ScriptExtender's ModVars.

local IStorageAdapter = require("Shared/DynamicSettings/Adapters/IStorageAdapter")

---@class ModVarAdapter : IStorageAdapter
local ModVarAdapter = {}
setmetatable(ModVarAdapter, { __index = IStorageAdapter })
ModVarAdapter.__index = ModVarAdapter

--- Completely overwrites the ModVars table for the given moduleUUID with the provided vars table.
--- This is necessary because ModVars will not update automatically for nested tables.
--- This requires a full dirty/sync of the table to take effect.
--- This is inexpensive for primitive values.
---@param vars table<string, any>
---@param moduleUUID? string
function ModVarAdapter:Sync(vars, moduleUUID)
    -- Redundant but worky :catyep:
    local modVars = Ext.Vars.GetModVariables(moduleUUID or ModuleUUID)
    if vars then
        for varName, _data in pairs(vars) do
            vars[varName] = vars[varName]
        end
        modVars = vars
        Ext.Vars.DirtyModVariables(moduleUUID or ModuleUUID)
        Ext.Vars.SyncModVariables(moduleUUID or ModuleUUID)
    end
end

--- Read a ModVar for this moduleUUID and key. Returns raw Lua value or nil.
---@param moduleUUID string The UUID of the module
---@param key string The key to read
---@return any value The raw Lua value or nil if not set
function ModVarAdapter:GetValue(key, moduleUUID)
    local vars = Ext.Vars.GetModVariables(moduleUUID)
    if not vars then
        return nil
    end
    local v = vars[key]
    -- SE returns nil if unset, or the stored Lua value (boolean/number/string/table).
    return v
end

--- Write a ModVar for (key, value, moduleUUID). If value==nil, remove that variable.
---@param key string The key to write
---@param value any The value to write (nil to delete)
---@param moduleUUID string The UUID of the module
function ModVarAdapter:SetValue(key, value, moduleUUID)
    local ok, err = pcall(function()
        local vars = Ext.Vars.GetModVariables(moduleUUID)
        if not vars then
            return
        end
        vars[key] = value
        self:Sync(vars, moduleUUID)
    end)
    if not ok then
        MCMWarn(0, "ModVarAdapter:SetValue() failed: " .. err)
    end
end

return ModVarAdapter
