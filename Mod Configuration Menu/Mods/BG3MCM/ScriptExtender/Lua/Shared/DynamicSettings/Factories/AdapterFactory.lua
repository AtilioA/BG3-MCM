-- Registers and provides storage adapters by storage ("modvar" or "modconfig").

local ModVarAdapter = require("Shared/DynamicSettings/Adapters/ModVarAdapter")
local ModConfigAdapter = require("Shared/DynamicSettings/Adapters/ModConfigAdapter")
local JsonAdapter = require("Shared/DynamicSettings/Adapters/JsonAdapter")

---@class AdapterFactory
local AdapterFactory = {
    ---@enum StorageType
    StorageType = {
        ModVar = "modvar",
        ModConfig = "modconfig",
        Json = "json"
    },
    adapters = {
        ["modvar"] = ModVarAdapter,
        ["modconfig"] = ModConfigAdapter,
        ["json"] = JsonAdapter
    }
}

--- Returns the adapter class (module) for this storage. Errors if none exists.
---@param storage string The type of storage ("modvar", "modconfig", etc.)
---@return table|nil adapter The adapter for the given storage type
function AdapterFactory.GetAdapter(storage)
    if not storage then return nil end
    local typeLower = string.lower(storage)
    local adapter = AdapterFactory.adapters[typeLower]
    if not adapter then
        MCMError(0, ("AdapterFactory: No adapter registered for storage '%s'"):format(storage))
    end
    return adapter
end

return AdapterFactory
