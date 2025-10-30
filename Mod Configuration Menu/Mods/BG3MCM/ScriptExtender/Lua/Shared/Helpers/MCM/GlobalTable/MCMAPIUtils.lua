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

return MCMAPIUtils
