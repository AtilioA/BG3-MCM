-- Shared mod validation logic for load order health checks.
---@class ModValidation: _Class
ModValidation = _Class:Create("ModValidation", nil, {})

--- Checks if a mod is relevant for load order health checks.
--- A relevant mod is one that is loaded and non-vanilla.
--- @param mod The mod to check.
--- @return boolean - True if the mod is relevant, false otherwise.
function ModValidation:IsModRelevant(mod)
    return mod and mod.Info and mod.Info.ModuleUUID and Ext.Mod.IsModLoaded(mod.Info.ModuleUUID)
        and mod.Info.Author ~= "" and mod.Info.Author ~= "LS"
end

return ModValidation
