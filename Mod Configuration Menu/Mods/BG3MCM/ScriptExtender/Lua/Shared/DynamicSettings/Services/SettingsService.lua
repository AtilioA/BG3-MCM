-- Central façade for managing (reading, writing, promoting) module-scoped variables.

local AdapterFactory = require("Shared/DynamicSettings/Factories/AdapterFactory")

---@class VariableEntry
---@field type string|nil The type of the variable ("boolean", "number", "string", "table", or nil)
---@field default any The default value for the variable
---@field validate fun(value: any): (boolean, string)? Optional validation function

---@class StorageBucket
---@field [string] VariableEntry Map of variable names to their entries

---@class ModuleSchema
---@field ModVar StorageBucket Variables stored in ModVars
---@field ModConfig StorageBucket Variables stored in ModConfig

---@class SettingsService
---@field schema table<string, ModuleSchema> Map of module UUIDs to their schemas
---@field serverSideVars table<string, table<string, table>> Map of module UUIDs to server-side variables
local SettingsService = {
    schema = {},
    serverSideVars = {}
}

--- INTERNAL: Coerce a rawValue into the declared type (if promoted), or accept raw.
---@param entry VariableEntry The entry for the mod variable
---@param rawValue any The mod variable's raw value to coerce and validate
---@return any - The coerced and validated value, or rawValue if none performed
local function coerceAndValidate(entry, rawValue)
    if entry.type then
        if entry.type == "boolean" then
            if type(rawValue) ~= "boolean" then
                MCMWarn(0, "Expected boolean, got " .. type(rawValue))
            end
            return rawValue
        elseif entry.type == "number" then
            if type(rawValue) ~= "number" then
                MCMWarn(0, "Expected number, got " .. type(rawValue))
            end
            return rawValue
        elseif entry.type == "table" then
            if type(rawValue) ~= "table" then
                MCMWarn(0, "Expected table, got " .. type(rawValue))
            end
            return rawValue
        elseif entry.type == "string" then
            if type(rawValue) ~= "string" then
                MCMWarn(0, "Expected string, got " .. type(rawValue))
            end
            return rawValue
        else
            MCMWarn(0, "Unknown promoted type: " .. tostring(entry.type))
        end
    else
        -- No promotion: return whatever SE stored (any Lua type)
        return rawValue
    end
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

    if not SettingsService.schema[moduleUUID] then
        SettingsService.schema[moduleUUID] = { ModVar = {}, ModConfig = {} }
    end

    local bucket = SettingsService.schema[moduleUUID][storageType]
    if bucket[varName] then
        return -- already registered
    end

    bucket[varName] = {
        type     = nil, -- will be set if/when user promotes
        default  = nil,
        validate = nil
    }
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
    end

    local bucket = modSchema[storageType]
    if not bucket or not bucket[varName] then
        MCMWarn(0, ("Cannot promote '%s' under %s for module %s; not discovered"):format(
            varName, storageType, moduleUUID))
    end

    -- Assign metadata
    bucket[varName].type     = definition.type
    bucket[varName].default  = definition.default
    bucket[varName].validate = definition.validate

    -- Immediately write default if no value exists
    local adapter            = AdapterFactory.GetAdapter(storageType)
    local raw                = adapter:GetValue(moduleUUID, varName)
    if raw == nil and definition.default ~= nil then
        adapter:SetValue(moduleUUID, varName, definition.default)
    else
        local ok, _val = pcall(coerceAndValidate, bucket[varName], raw)
        if not ok then
            adapter:SetValue(moduleUUID, varName, definition.default)
        end
    end
end

--- GET: Retrieve the current Lua value for (moduleUUID, varName, storageType).
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param storageType string The type of storage ("ModVar", "ModConfig", etc.)
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

    if not storageType then
        MCMWarn(0, "Get: storageType cannot be nil")
        return nil
    end

    local modSchema = SettingsService.schema[moduleUUID]
    if not modSchema then
        MCMWarn(0, "No variables known for module " .. moduleUUID)
    end

    local bucket = modSchema[storageType]
    if not bucket or not bucket[varName] then
        MCMWarn(0, ("Get: '%s' under %s not discovered for module %s"):format(
            varName, storageType, moduleUUID))
    end

    local entry = bucket[varName]
    local adapter = AdapterFactory.GetAdapter(storageType)
    local raw = adapter:GetValue(moduleUUID, varName)

    if raw == nil then
        return nil
    end

    local ok, val = pcall(coerceAndValidate, entry, raw)
    if not ok then
        MCMWarn(0, ("Get: coercion failed for %s:%s in %s: %s"):format(
            moduleUUID, varName, storageType, val))
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
    end

    local result = {}
    for storageType, bucket in pairs(modSchema) do
        result[storageType] = {}
        local adapter = AdapterFactory.GetAdapter(storageType)
        for varName, entry in pairs(bucket) do
            local raw = adapter:GetValue(moduleUUID, varName)
            if raw ~= nil then
                local ok, val = pcall(coerceAndValidate, entry, raw)
                if ok then
                    result[storageType][varName] = val
                else
                    MCMWarn(0, ("GetAll: coercion failed for %s:%s in %s: %s"):format(
                        moduleUUID, varName, storageType, val))
                end
            end
        end
    end

    return result
end

--- SET: Write a new Lua value for (moduleUUID, varName, storageType), then emit event.
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param storageType string The type of storage ("ModVar", "ModConfig", etc.)
---@param newValue any The new value to set
function SettingsService.Set(moduleUUID, varName, storageType, newValue)
    if not moduleUUID then
        MCMWarn(0, "Set: moduleUUID cannot be nil")
        return
    end

    if not varName then
        MCMWarn(0, "Set: varName cannot be nil")
        return
    end

    if not storageType then
        MCMWarn(0, "Set: storageType cannot be nil")
        return
    end

    if not newValue then
        MCMWarn(0, "Set: newValue cannot be nil")
        return
    end

    local modSchema = SettingsService.schema[moduleUUID]
    if not modSchema then
        MCMWarn(0, "No variables known for module " .. moduleUUID)
    end

    local bucket = modSchema[storageType]
    if not bucket or not bucket[varName] then
        MCMWarn(0, ("Set: '%s' under %s not discovered for module %s"):format(
            varName, storageType, moduleUUID))
    end

    local entry = bucket[varName]
    if entry.validate then
        local ok, errMsg = entry.validate(newValue)
        if not ok then
            MCMWarn(0, ("Validation failed for %s:%s in %s: %s"):format(
                moduleUUID, varName, storageType, errMsg))
        end
    end

    local ok, val = pcall(coerceAndValidate, entry, newValue)
    if not ok then
        MCMWarn(0, ("Set: coercion failed for %s:%s in %s: %s"):format(
            moduleUUID, varName, storageType, val))
    end

    local adapter = AdapterFactory.GetAdapter(storageType)

    --FIXME: deepcopy oldValue since it may be a table
    local oldValue = adapter:GetValue(moduleUUID, varName)
    adapter:SetValue(moduleUUID, varName, val)

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
end

-- SERVER VARIABLES: Register a server-side variable discovered on the server
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param varType string The type of the variable
---@param value any The current value of the variable
function SettingsService.RegisterServerVariable(moduleUUID, varName, varType, value)
    if not moduleUUID then
        MCMWarn(0, "RegisterServerVariable: moduleUUID cannot be nil")
        return
    end

    if not varName then
        MCMWarn(0, "RegisterServerVariable: varName cannot be nil")
        return
    end

    if not SettingsService.serverSideVars[moduleUUID] then
        SettingsService.serverSideVars[moduleUUID] = {}
    end

    SettingsService.serverSideVars[moduleUUID][varName] = {
        type = varType,
        value = value
    }
end

-- SERVER VARIABLES: Get all server-side variables for a module
---@param moduleUUID string The UUID of the module
---@return table<string, table> A table of variable names to their entries
function SettingsService.GetServerVariables(moduleUUID)
    if not moduleUUID then
        MCMWarn(0, "GetServerVariables: moduleUUID cannot be nil")
        return {}
    end

    return SettingsService.serverSideVars[moduleUUID] or {}
end

-- SERVER VARIABLES: Get all server-side variables for all modules
---@return table<string, table<string, table>> A table of module UUIDs to their variables
function SettingsService.GetAllServerVariables()
    return SettingsService.serverSideVars
end

-- SERVER VARIABLES: Update a server-side variable's value
---@param moduleUUID string The UUID of the module
---@param varName string The name of the variable
---@param newValue any The new value to set
function SettingsService.UpdateServerVariable(moduleUUID, varName, newValue)
    if not moduleUUID then
        MCMWarn(0, "UpdateServerVariable: moduleUUID cannot be nil")
        return
    end

    if not varName then
        MCMWarn(0, "UpdateServerVariable: varName cannot be nil")
        return
    end

    if not SettingsService.serverSideVars[moduleUUID] then
        MCMWarn(0, "UpdateServerVariable: No variables known for module " .. moduleUUID)
        return
    end

    if not SettingsService.serverSideVars[moduleUUID][varName] then
        MCMWarn(0, "UpdateServerVariable: Variable '" .. varName .. "' not found for module " .. moduleUUID)
        return
    end

    local oldValue = SettingsService.serverSideVars[moduleUUID][varName].value
    SettingsService.serverSideVars[moduleUUID][varName].value = newValue

    -- Emit a server variable updated event for any listeners
    ModEventManager:Emit(
        EventChannels.MCM_SERVER_VARS_UPDATED,
        {
            modUUID  = moduleUUID,
            key      = varName,
            oldValue = oldValue,
            value    = newValue
        },
        true
    )
end

return SettingsService
