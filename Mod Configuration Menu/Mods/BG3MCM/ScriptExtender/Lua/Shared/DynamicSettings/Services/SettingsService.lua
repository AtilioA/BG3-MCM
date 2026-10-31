-- Central façade for registering, reading, and writing module-scoped variables.

Ext.Require("Shared/DynamicSettings/Factories/AdapterFactory.lua")

---@class VariableEntry
---@field type string|nil The type of the variable ("boolean", "number", "string", "table", or nil)
---@field default StorageValue The default value for the variable
---@field validate fun(value: unknown): (boolean, string)? Optional validation function
---@field storageType string The storage type for this variable
---@field storageConfig table|nil Optional storage-specific configuration (e.g., SE ModVar parameters)

---@class StorageBucket
---@field [string] VariableEntry Map of variable names to their entries

---@class ModuleSchema
---@field [string] StorageBucket Dynamic storage buckets (ModVar, ModConfig, Json, etc.)

---@class SettingsService
---@field schema table<string, ModuleSchema> Map of module UUIDs to their schemas
---@field varToStorageType table<string, table<string, string>> Map UUID -> varName -> storageType for quick lookup
SettingsService = {
    schema = {},
    varToStorageType = {}
}

--- Get or create the schema for a module
---@param moduleUUID string
---@return ModuleSchema
local function getModSchema(moduleUUID)
    if not SettingsService.schema[moduleUUID] then
        SettingsService.schema[moduleUUID] = {}
    end
    return SettingsService.schema[moduleUUID]
end

--- Get or create a storage bucket for a module
---@param moduleUUID string
---@param storageType string
---@return StorageBucket
local function getStorageBucket(moduleUUID, storageType)
    local modSchema = getModSchema(moduleUUID)
    if not modSchema[storageType] then
        modSchema[storageType] = {}
    end
    return modSchema[storageType]
end

--- INTERNAL: Check rawValue against the declared type (if any) and the validator, then return it.
---@param entry VariableEntry The entry for the mod variable
---@param rawValue any The mod variable's raw value to validate
---@return StorageValue - rawValue, when it is valid
local function coerceAndValidate(entry, rawValue)
    local declared = entry.type
    if declared and declared ~= "boolean" and declared ~= "number" and declared ~= "string" and declared ~= "table" then
        MCMWarn(0, "Unknown declared type: %s", declared)
    elseif declared and type(rawValue) ~= declared then
        error("Expected " .. declared .. ", got " .. type(rawValue))
    end

    if entry.validate and rawValue ~= nil then
        local ok, errMsg = entry.validate(rawValue)
        if not ok then
            error("Validation failed: " .. (errMsg or "unknown error"))
        end
    end

    return rawValue
end

--- REGISTER: One-step registration of a variable with type and default value.
--- This is the primary public API method for registering variables.
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param storageType string A known storage type ("modvar", "modconfig", "json")
---@param definition table { type=<"boolean"|"number"|"string"|"table">|nil, default=<any>|nil, validate=<fn>|nil, storageConfig=<StorageConfig>|nil }
---@return boolean success True if registered successfully
function SettingsService.Register(moduleUUID, varName, storageType, definition)
    local adapter = AdapterFactory.GetAdapter(storageType)

    -- Register the underlying storage prototype eagerly. This MUST happen now (i.e. when the mod calls MCM.Store.RegisterVar at bootstrap) so SE can restore a ModVar's persisted value BEFORE SessionLoaded.
    -- A rejected registration (e.g. a conflicting JSON fileName) keeps the first entry; the adapter reports why.
    if not adapter:EnsureRegistered(varName, moduleUUID, definition.storageConfig) then
        return false
    end

    local bucket = getStorageBucket(moduleUUID, storageType)

    -- Register the variable entry
    bucket[varName] = {
        type = definition.type,
        default = definition.default,
        validate = definition.validate,
        storageType = storageType,
        storageConfig = definition.storageConfig
    }

    -- Track storage type for quick lookup
    SettingsService.varToStorageType[moduleUUID] = SettingsService.varToStorageType[moduleUUID] or {}
    SettingsService.varToStorageType[moduleUUID][varName] = storageType

    -- Seed the default only if no value exists. RunWhenReady lets backends (e.g. ModVar) evaluate AFTER the savegame value is restored, never clobbering it; backends such as JSON run immediately.
    if definition.default ~= nil and adapter:OwnsDefaults(definition.storageConfig) then
        adapter:RunWhenReady(function()
            if adapter:GetValue(varName, moduleUUID, definition.storageConfig) == nil then
                adapter:SetValue(varName, definition.default, moduleUUID, definition.storageConfig)
            end
        end)
    end

    MCMDebug(2,
        "SettingsService: Registered '%s' for mod %s (storage: %s)", varName, moduleUUID, storageType)
    return true
end

--- Get the storage type for a registered variable
---@param moduleUUID string
---@param varName string
---@return string|nil storageType The storage type, or nil if not registered
function SettingsService.GetStorageType(moduleUUID, varName)
    local modMap = SettingsService.varToStorageType[moduleUUID]
    return modMap and modMap[varName]
end

--- Get the storageConfig a variable was registered with
---@param moduleUUID string
---@param varName string
---@return StorageConfig|nil storageConfig The registered config, or nil if the variable is not registered or has none
function SettingsService.GetStorageConfig(moduleUUID, varName)
    local storageType = SettingsService.GetStorageType(moduleUUID, varName)
    local entry = storageType and getStorageBucket(moduleUUID, storageType)[varName]
    return entry and entry.storageConfig or nil
end

--- Resolve the storage type of a variable, warning when it is not registered
---@param moduleUUID string
---@param varName string
---@param methodName string Use for error reporting
---@return string? storageType The resolved storage type
function SettingsService.ResolveStorageType(moduleUUID, varName, methodName)
    local storageType = SettingsService.GetStorageType(moduleUUID, varName)
    if not storageType then
        MCMWarn(0, "%s: Variable '%s' not registered for module %s", methodName, varName, moduleUUID)
    end
    return storageType
end

-- DISCOVERY: Register every discovered (moduleUUID, varName, storageType).
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param storageType string The type of storage ("ModVar", "ModConfig", etc.)
function SettingsService.RegisterDiscoveredVariable(moduleUUID, varName, storageType)
    local bucket = getStorageBucket(moduleUUID, storageType)
    if bucket[varName] then
        return -- already registered
    end

    bucket[varName] = {
        type          = nil,
        default       = nil,
        validate      = nil,
        storageType   = storageType,
        storageConfig = nil
    }

    -- Track storage type for quick lookup
    SettingsService.varToStorageType[moduleUUID] = SettingsService.varToStorageType[moduleUUID] or {}
    SettingsService.varToStorageType[moduleUUID][varName] = storageType
end

--- GET: Retrieve the current Lua value for (moduleUUID, varName).
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@return StorageValue value The value of the variable
function SettingsService.Get(moduleUUID, varName)
    local storageType = SettingsService.ResolveStorageType(moduleUUID, varName, "Get")
    if not storageType then
        return nil
    end

    local entry = getStorageBucket(moduleUUID, storageType)[varName]
    local adapter = AdapterFactory.GetAdapter(storageType)
    local raw = adapter:GetValue(varName, moduleUUID, entry.storageConfig) or nil

    -- If nil, return registered default
    if raw == nil then
        return entry.default
    end

    local ok, val = pcall(coerceAndValidate, entry, raw)
    if not ok then
        MCMWarn(0,
            "Get: Validation/Coercion failed for %s (%s) for type %s: %s. Reverting setting value to default: %s.",
            moduleUUID, varName, storageType, val, entry.default)

        -- REVIEW: if default is not defined, should we return nil?
        -- If it's defined as nil, we should return nil...
        val = entry.default
        adapter:SetValue(varName, val, moduleUUID, entry.storageConfig)
    end

    return val
end

--- GETALL for a specific storage type only
---@param moduleUUID string The UUID of the module
---@param storageType string A known storage type to get values for
---@return table<string, any> - A flat table of varName -> value
function SettingsService.GetAllForStorageType(moduleUUID, storageType)
    local modSchema = SettingsService.schema[moduleUUID]
    local bucket = modSchema and modSchema[storageType]
    if not bucket then
        return {}
    end

    local result = {}
    local adapter = AdapterFactory.GetAdapter(storageType)
    for varName, entry in pairs(bucket) do
        local raw = adapter:GetValue(varName, moduleUUID, entry.storageConfig)
        if raw ~= nil then
            local ok, val = pcall(coerceAndValidate, entry, raw)
            if ok then
                result[varName] = val
            end
        else
            result[varName] = entry.default
        end
    end

    return result
end

--- Whether a value for (moduleUUID, varName) can be saved; false when, for example, its JSON file failed to parse.
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@return boolean writable
function SettingsService.IsWritable(moduleUUID, varName)
    local storageType = SettingsService.ResolveStorageType(moduleUUID, varName, "IsWritable")
    return storageType ~= nil and AdapterFactory.GetAdapter(storageType):IsWritable(varName, moduleUUID)
end

--- SET: Write a new Lua value for (moduleUUID, varName), storage type auto-detected.
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param newValue any The new value to set; nil, false, and 0 are all valid
---@return boolean success True if value was set
function SettingsService.Set(moduleUUID, varName, newValue)
    local storageType = SettingsService.ResolveStorageType(moduleUUID, varName, "Set")
    if not storageType then
        return false
    end

    local entry = getStorageBucket(moduleUUID, storageType)[varName]
    local adapter = AdapterFactory.GetAdapter(storageType)

    -- Validate and coerce. If fails, revert to default.
    local ok, result = pcall(coerceAndValidate, entry, newValue)
    if not ok then
        MCMWarn(0, "Set: Validation/Coercion failed for %s (%s) in %s: %s. Reverting to default: %s.",
            moduleUUID, varName, storageType, result, entry.default)

        -- REVIEW: if default is not defined, should we return nil?
        -- If it's defined as nil, we should return nil...
        if entry.default ~= nil then
            -- A refused write keeps the old value, so there is no save to report
            if adapter:SetValue(varName, entry.default, moduleUUID, entry.storageConfig) == false then
                return false
            end

            -- Emit a setting saved event for the correction
            ModEventManager:Emit(
                EventChannels.MCM_DYNAMIC_SETTING_SAVED,
                {
                    modUUID     = moduleUUID,
                    key         = varName,
                    storageType = storageType,
                    oldValue    = newValue,     -- The bad value that was attempted
                    value       = entry.default -- The default value it was reverted to
                },
                true
            )
        end
        return false
    end

    local oldValue = table.deepcopy(adapter:GetValue(varName, moduleUUID, entry.storageConfig) or nil)
    -- A refused write (e.g. an unreadable JSON file) keeps the old value; the adapter logs why
    if adapter:SetValue(varName, result, moduleUUID, entry.storageConfig) == false then
        return false
    end

    -- Emit a setting saved event for any listeners
    ModEventManager:Emit(
        EventChannels.MCM_DYNAMIC_SETTING_SAVED,
        {
            modUUID     = moduleUUID,
            key         = varName,
            storageType = storageType,
            oldValue    = oldValue,
            value       = result
        },
        true
    )

    MCMDebug(3, "SettingsService: Set '%s' = %s for mod %s", varName, tostring(result), moduleUUID)
    return true
end

return SettingsService
