local MCMAPIUtils = {}

-- Shared state for deprecation warnings
local warnedDeprecation = {}

--- Helper function to show a deprecation warning once per mod and method
---@param modUUID string - The UUID of the mod showing the warning
---@param methodName string The name of the deprecated method
---@param message string The deprecation message
function MCMAPIUtils.WarnOnce(modUUID, methodName, message)
    if not warnedDeprecation[modUUID] then
        warnedDeprecation[modUUID] = {}
    end
    if not warnedDeprecation[modUUID][methodName] then
        MCMDeprecation(1, Ext.Mod.GetMod(modUUID).Info.Name .. ": " .. message)
        warnedDeprecation[modUUID][methodName] = true
    end
end

function MCMAPIUtils.EnsureModUUID(providedUUID, defaultUUID)
    return providedUUID or defaultUUID
end

--- Normalize arguments for hybrid (table or positional) APIs.
--- Detects whether the first argument is a named table or positional arguments,
--- and returns a normalized table with all parameters properly mapped.
---@param arg1 any First argument (either a table or first positional value)
---@param positionalNames string[] List of parameter names in positional order
---@param defaults? table<string, any> Default values for optional parameters
---@param ... any Additional positional arguments
---@return table args Normalized argument table with all parameters
function MCMAPIUtils.NormalizeArgs(arg1, positionalNames, defaults, ...)
    -- Check if arg1 is a named table (non-array table or empty table)
    if type(arg1) == "table" and (#arg1 == 0 or next(arg1, #arg1) ~= nil) then
        local args = {}
        -- Apply defaults first
        for k, v in pairs(defaults or {}) do
            args[k] = (arg1[k] ~= nil) and arg1[k] or v
        end
        -- Override with provided values
        for k, v in pairs(arg1) do
            args[k] = v
        end
        return args
    end

    -- Handle positional arguments
    local values = { arg1, ... }
    local args = {}
    for i, name in ipairs(positionalNames) do
        args[name] = values[i]
    end
    -- Apply defaults for missing values
    for k, v in pairs(defaults or {}) do
        if args[k] == nil then args[k] = v end
    end
    return args
end

--- Create a flexible wrapper function that accepts both table and positional arguments.
--- The returned function will automatically normalize arguments before calling the implementation.
---@param fn function The implementation function that expects a single table argument
---@param positionalNames string[] List of parameter names in positional order
---@param defaults? table<string, any> Default values for optional parameters
---@return function wrapper A wrapper function that accepts flexible arguments
function MCMAPIUtils.WithFlexibleArgs(fn, positionalNames, defaults)
    return function(arg1, ...)
        local args = MCMAPIUtils.NormalizeArgs(arg1, positionalNames, defaults, ...)
        return fn(args)
    end
end

return MCMAPIUtils
