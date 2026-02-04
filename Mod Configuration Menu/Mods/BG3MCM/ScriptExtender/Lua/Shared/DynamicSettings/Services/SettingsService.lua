-- Central façade for managing (reading, writing, promoting) module-scoped variables.

local AdapterFactory = require("Shared/DynamicSettings/Factories/AdapterFactory")

---@class VariableEntry
---@field type string|nil The type of the variable ("boolean", "number", "string", "table", or nil)
---@field default any The default value for the variable
---@field validate fun(value: any): (boolean, string)? Optional validation function
---@field storageType string The storage type for this variable
---@field storageConfig table|nil Optional storage-specific configuration (e.g., SE ModVar parameters)

---@class StorageBucket
---@field [string] VariableEntry Map of variable names to their entries

---@class ModuleSchema
---@field [string] StorageBucket Dynamic storage buckets (ModVar, ModConfig, Json, etc.)

---@class SettingsService
---@field schema table<string, ModuleSchema> Map of module UUIDs to their schemas
---@field varToStorageType table<string, table<string, string>> Map UUID -> varName -> storageType for quick lookup
local SettingsService = {
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

--- INTERNAL: Coerce a rawValue into the declared type (if promoted), or accept raw.
---@param entry VariableEntry The entry for the mod variable
---@param rawValue any The mod variable's raw value to coerce and validate
---@return any - The coerced and validated value, or rawValue if none performed
local function coerceAndValidate(entry, rawValue)
    if entry.type then
        if entry.type == "boolean" then
            if type(rawValue) ~= "boolean" then
                error("Expected boolean, got " .. type(rawValue))
            end
        elseif entry.type == "number" then
            if type(rawValue) ~= "number" then
                error("Expected number, got " .. type(rawValue))
            end
        elseif entry.type == "table" then
            if type(rawValue) ~= "table" then
                error("Expected table, got " .. type(rawValue))
            end
        elseif entry.type == "string" then
            if type(rawValue) ~= "string" then
                error("Expected string, got " .. type(rawValue))
            end
        else
            MCMWarn(0, "Unknown promoted type: " .. tostring(entry.type))
        end
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
---@param storageType string The type of storage ("ModVar", "ModConfig", "Json", etc.)
---@param definition? table { type=<"boolean"|"number"|"string"|"table">|nil, default=<any>|nil, validate=<fn>|nil, storageConfig=<table>|nil }
---@return boolean success True if registered successfully
function SettingsService.Register(moduleUUID, varName, storageType, definition)
    if not moduleUUID then
        MCMWarn(0, "Register: moduleUUID cannot be nil")
        return false
    end

    if not varName then
        MCMWarn(0, "Register: varName cannot be nil")
        return false
    end

    if not storageType then
        MCMWarn(0, "Register: storageType cannot be nil")
        return false
    end

    definition = definition or {}

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
    if not SettingsService.varToStorageType[moduleUUID] then
        SettingsService.varToStorageType[moduleUUID] = {}
    end
    SettingsService.varToStorageType[moduleUUID][varName] = storageType

    -- If no value exists yet, write the default
    local adapter = AdapterFactory.GetAdapter(storageType)
    if adapter then
        local raw = adapter:GetValue(varName, moduleUUID)
        if raw == nil and definition.default ~= nil then
            adapter:SetValue(varName, definition.default, moduleUUID, definition.storageConfig)
        end
    else
        MCMWarn(0, ("Register: No adapter found for storage type '%s'"):format(storageType))
        return false
    end

    MCMDebug(2,
        string.format("SettingsService: Registered '%s' for mod %s (storage: %s)", varName, moduleUUID, storageType))
    return true
end

--- Get the storage type for a registered variable
---@param moduleUUID string
---@param varName string
---@return string|nil storageType The storage type, or nil if not registered
function SettingsService.GetStorageType(moduleUUID, varName)
    local modMap = SettingsService.varToStorageType[moduleUUID]
    if modMap then
        return modMap[varName]
    end
    return nil
end

--- Resolve the storage type for a variable, either from provided arg or auto-detection
---@param moduleUUID string
---@param varName string
---@param providedStorageType? string
---@param methodName string Use for error reporting
---@return string? storageType The resolved storage type
function SettingsService.ResolveStorageType(moduleUUID, varName, providedStorageType, methodName)
    if providedStorageType then
        return providedStorageType
    end

    local storageType = SettingsService.GetStorageType(moduleUUID, varName)
    if not storageType then
        MCMWarn(0, ("%s: Variable '%s' not registered for module %s"):format(methodName, varName, moduleUUID))
    end
    return storageType
end

-- DISCOVERY: Register every discovered (moduleUUID, varName, storageType).
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param storageType string The type of storage ("ModVar", "ModConfig", etc.)
function SettingsService.RegisterDiscoveredVariable(moduleUUID, varName, storageType)
    if not moduleUUID then
        MCMWarn(0, "RegisterDiscoveredVariable: moduleUUID cannot be nil")
        return
    end

    if not varName then
        MCMWarn(0, "RegisterDiscoveredVariable: varName cannot be nil")
        return
    end

    if not storageType then
        MCMWarn(0, "RegisterDiscoveredVariable: storageType cannot be nil")
        return
    end

    local bucket = getStorageBucket(moduleUUID, storageType)
    if bucket[varName] then
        return -- already registered
    end

    bucket[varName] = {
        type          = nil, -- will be set if/when user promotes
        default       = nil,
        validate      = nil,
        storageType   = storageType,
        storageConfig = nil
    }

    -- Track storage type for quick lookup
    if not SettingsService.varToStorageType[moduleUUID] then
        SettingsService.varToStorageType[moduleUUID] = {}
    end
    SettingsService.varToStorageType[moduleUUID][varName] = storageType
end

--- PROMOTION: Turn an untyped variable into a typed setting.
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param storageType string The type of storage ("ModVar", "ModConfig", etc.)
---@param definition table { type=<"boolean"|"number"|"string"|"table">, default=<any>, validate=<fn>|nil }
function SettingsService.PromoteVariable(moduleUUID, varName, storageType, definition)
    if not moduleUUID then
        MCMWarn(0, "PromoteVariable: moduleUUID cannot be nil")
        return
    end

    if not varName then
        MCMWarn(0, "PromoteVariable: varName cannot be nil")
        return
    end

    if not storageType then
        MCMWarn(0, "PromoteVariable: storageType cannot be nil")
        return
    end

    if not definition then
        MCMWarn(0, "PromoteVariable: definition cannot be nil")
        return
    end

    local modSchema = SettingsService.schema[moduleUUID]
    if not modSchema then
        MCMWarn(0, "No variables known for module " .. moduleUUID)
        return
    end

    local bucket = modSchema[storageType]
    if not bucket or not bucket[varName] then
        MCMWarn(0, ("Cannot promote '%s' under %s for module %s; not discovered"):format(
            varName, storageType, moduleUUID))
        return
    end

    -- Assign metadata
    bucket[varName].type          = definition.type
    bucket[varName].default       = definition.default
    bucket[varName].validate      = definition.validate
    bucket[varName].storageConfig = definition.storageConfig

    -- Immediately write default if no value exists
    local adapter                 = AdapterFactory.GetAdapter(storageType)
    local raw                     = adapter:GetValue(varName, moduleUUID)
    if raw == nil and definition.default ~= nil then
        adapter:SetValue(varName, definition.default, moduleUUID, definition.storageConfig)
    else
        local ok, _val = pcall(coerceAndValidate, bucket[varName], raw)
        if not ok then
            adapter:SetValue(varName, definition.default, moduleUUID, definition.storageConfig)
        end
    end
end

--- GET: Retrieve the current Lua value for (moduleUUID, varName).
--- Storage type is auto-detected if not provided.
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param storageType? string The type of storage, or nil to auto-detect
---@return any value The value of the variable
function SettingsService.Get(moduleUUID, varName, storageType)
    if not moduleUUID then
        MCMWarn(0, "Get: moduleUUID cannot be nil")
        return nil
    end

    if not varName then
        MCMWarn(0, "Get: varName cannot be nil")
        return nil
    end

    -- Auto-detect storage type if not provided
    storageType = SettingsService.ResolveStorageType(moduleUUID, varName, storageType, "Get")
    if not storageType then
        return nil
    end

    local modSchema = SettingsService.schema[moduleUUID]
    if not modSchema then
        MCMWarn(0, "No variables known for module " .. moduleUUID)
        return nil
    end

    local bucket = modSchema[storageType]
    if not bucket or not bucket[varName] then
        MCMWarn(0, ("Get: '%s' under %s not discovered for module %s"):format(
            varName, storageType, moduleUUID))
        return nil
    end

    local entry = bucket[varName]
    local adapter = AdapterFactory.GetAdapter(storageType)
    local raw = adapter:GetValue(varName, moduleUUID)

    -- If nil, return registered default
    if raw == nil then
        if entry.default ~= nil then
            return entry.default
        end
        return nil
    end

    local ok, val = pcall(coerceAndValidate, entry, raw)
    if not ok then
        MCMWarn(0,
            ("Get: Validation/Coercion failed for %s (%s) for type %s: %s. Reverting setting value to default: %s.")
            :format(
                moduleUUID, varName, storageType, val, entry.default))

        -- REVIEW: if default is not defined, should we return nil?
        -- If it's defined as nil, we should return nil...
        val = entry.default
        adapter:SetValue(varName, val, moduleUUID, entry.storageConfig)
    end

    return val
end

--- GETALL: Retrieve the current value of all variables for a module
---@param moduleUUID string The UUID of the module
---@return table<string, any> - A table containing all variables and their values
function SettingsService.GetAll(moduleUUID)
    if not moduleUUID then
        MCMWarn(0, "GetAll: moduleUUID cannot be nil")
        return {}
    end

    local modSchema = SettingsService.schema[moduleUUID]
    if not modSchema then
        MCMWarn(0, "No variables known for module " .. moduleUUID)
        return {}
    end

    local result = {}
    for storageType, bucket in pairs(modSchema) do
        result[storageType] = {}
        local adapter = AdapterFactory.GetAdapter(storageType)
        for varName, entry in pairs(bucket) do
            local raw = adapter:GetValue(varName, moduleUUID)
            if raw ~= nil then
                local ok, val = pcall(coerceAndValidate, entry, raw)
                if ok then
                    result[storageType][varName] = val
                else
                    MCMWarn(0, ("GetAll: coercion failed for %s:%s in %s: %s"):format(
                        moduleUUID, varName, storageType, val))
                end
            elseif entry.default ~= nil then
                result[storageType][varName] = entry.default
            end
        end
    end

    return result
end

--- GETALL for a specific storage type only
---@param moduleUUID string The UUID of the module
---@param storageType string The storage type to get values for
---@return table<string, any> - A flat table of varName -> value
function SettingsService.GetAllForStorageType(moduleUUID, storageType)
    if not moduleUUID then
        MCMWarn(0, "GetAllForStorageType: moduleUUID cannot be nil")
        return {}
    end

    if not storageType then
        MCMWarn(0, "GetAllForStorageType: storageType cannot be nil")
        return {}
    end

    local modSchema = SettingsService.schema[moduleUUID]
    if not modSchema then
        return {}
    end

    local bucket = modSchema[storageType]
    if not bucket then
        return {}
    end

    local result = {}
    local adapter = AdapterFactory.GetAdapter(storageType)
    for varName, entry in pairs(bucket) do
        local raw = adapter:GetValue(varName, moduleUUID)
        if raw ~= nil then
            local ok, val = pcall(coerceAndValidate, entry, raw)
            if ok then
                result[varName] = val
            end
        elseif entry.default ~= nil then
            result[varName] = entry.default
        end
    end

    return result
end

--- SET: Write a new Lua value for (moduleUUID, varName), storage type auto-detected.
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param newValue any The new value to set
---@param storageType? string The type of storage, or nil to auto-detect
---@return boolean success True if value was set
function SettingsService.Set(moduleUUID, varName, newValue, storageType)
    if not moduleUUID then
        MCMWarn(0, "Set: moduleUUID cannot be nil")
        return false
    end

    if not varName then
        MCMWarn(0, "Set: varName cannot be nil")
        return false
    end

    -- newValue can be nil, false, 0 - these are all valid values
    -- We only reject if varName is nil

    -- Auto-detect storage type if not provided
    storageType = SettingsService.ResolveStorageType(moduleUUID, varName, storageType, "Set")
    if not storageType then
        return false
    end

    local modSchema = SettingsService.schema[moduleUUID]
    if not modSchema then
        MCMWarn(0, "No variables known for module " .. moduleUUID)
        return false
    end

    local bucket = modSchema[storageType]
    if not bucket or not bucket[varName] then
        MCMWarn(0, ("Set: '%s' under %s not discovered for module %s"):format(
            varName, storageType, moduleUUID))
        return false
    end

    local entry = bucket[varName]
    local val = newValue
    local adapter = AdapterFactory.GetAdapter(storageType)

    -- Validate and coerce. If fails, revert to default.
    local ok, result = pcall(coerceAndValidate, entry, newValue)
    if not ok then
        MCMWarn(0, ("Set: Validation/Coercion failed for %s (%s) in %s: %s. Reverting to default: %s."):format(
            moduleUUID, varName, storageType, result, entry.default))

        -- REVIEW: if default is not defined, should we return nil?
        -- If it's defined as nil, we should return nil...
        if entry.default ~= nil then
            val = entry.default
            adapter:SetValue(varName, val, moduleUUID, entry.storageConfig)

            -- Emit a setting saved event for the correction
            ModEventManager:Emit(
                EventChannels.MCM_DYNAMIC_SETTING_SAVED,
                {
                    modUUID     = moduleUUID,
                    key         = varName,
                    storageType = storageType,
                    oldValue    = newValue, -- The bad value that was attempted
                    value       = val       -- The default value it was reverted to
                },
                true
            )
        end
        return false
    end
    val = result

    --FIXME: deepcopy oldValue since it may be a table
    local oldValue = adapter:GetValue(varName, moduleUUID)
    adapter:SetValue(varName, val, moduleUUID, entry.storageConfig)

    -- Emit a setting saved event for any listeners
    ModEventManager:Emit(
        EventChannels.MCM_DYNAMIC_SETTING_SAVED,
        {
            modUUID     = moduleUUID,
            key         = varName,
            storageType = storageType,
            oldValue    = oldValue,
            value       = val
        },
        true
    )

    MCMDebug(3, string.format("SettingsService: Set '%s' = %s for mod %s", varName, tostring(val), moduleUUID))
    return true
end

return SettingsService
