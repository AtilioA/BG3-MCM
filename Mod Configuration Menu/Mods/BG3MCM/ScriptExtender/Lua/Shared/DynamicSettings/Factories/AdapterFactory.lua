-- Registers and provides storage adapters by storageType ("ModVar" or "ModConfig").

---@class AdapterFactory
local AdapterFactory = {
    adapters = {}
}

local ModVarAdapter = require("Shared/DynamicSettings/Adapters/ModVarAdapter")
local ModConfigAdapter = require("Shared/DynamicSettings/Adapters/ModConfigAdapter")
local JsonAdapter = require("Shared/DynamicSettings/Adapters/JsonAdapter")

--- Call once (e.g. in SessionLoading) to register each adapter class.
function AdapterFactory.Initialize()
    -- REVIEW: use enum for storage types?
    AdapterFactory.adapters["ModVar"]    = ModVarAdapter
    AdapterFactory.adapters["ModConfig"] = ModConfigAdapter
    AdapterFactory.adapters["Json"]      = JsonAdapter
    -- Later, to add other storage types:
    -- AdapterFactory.adapters["LocalSettings"] = LocalSettingsAdapter
end

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
