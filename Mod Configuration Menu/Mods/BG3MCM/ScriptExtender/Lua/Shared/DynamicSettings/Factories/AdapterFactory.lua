-- Registers and provides storage adapters by storageType ("ModVar" or "ModConfig").

local ModVarAdapter = require("Shared/DynamicSettings/Adapters/ModVarAdapter")
local ModConfigAdapter = require("Shared/DynamicSettings/Adapters/ModConfigAdapter")
local JsonAdapter = require("Shared/DynamicSettings/Adapters/JsonAdapter")

---@class AdapterFactory
local AdapterFactory = {
    adapters = {
        ["ModVar"] = ModVarAdapter,
        ["ModConfig"] = ModConfigAdapter,
        ["Json"] = JsonAdapter
    }
}

--- Returns the adapter class (module) for this storageType. Errors if none exists.
---@param storageType string The type of storage ("ModVar", "ModConfig", etc.)
---@return table adapter The adapter for the given storage type
function AdapterFactory.GetAdapter(storageType)
    local adapter = AdapterFactory.adapters[storageType]
    if not adapter then
        MCMError(0, ("AdapterFactory: No adapter registered for storageType '%s'"):format(storageType))
    end
    return adapter
end

return AdapterFactory
