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
        MCMError(0, "AdapterFactory: No adapter registered for storage '%s'", storage)
    end
    return adapter
end

--- True if `storage` maps to a registered adapter (case-insensitive).
---@param storage StorageType Candidate storage type
---@return boolean known
function AdapterFactory.IsKnown(storage)
    return type(storage) == "string" and AdapterFactory.adapters[string.lower(storage)] ~= nil
end

--- Sorted, quoted list of registered storage types, for diagnostics.
---@return string list e.g. "'json', 'modconfig', 'modvar'"
function AdapterFactory.KnownTypesList()
    local names = {}
    for storage in pairs(AdapterFactory.adapters) do
        names[#names + 1] = string.format("'%s'", storage)
    end
    table.sort(names)
    return table.concat(names, ", ")
end

return AdapterFactory
