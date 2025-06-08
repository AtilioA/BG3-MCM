---@class MCMPrecedenceCheck: _Class
MCMPrecedenceCheck = _Class:Create("MCMPrecedenceCheck", nil, {})

-- Returns a list of mods with an MCM blueprint that are loaded before MCM itself.
function MCMPrecedenceCheck.GetPrecedenceViolations()
    local loadOrder = Ext.Mod.GetLoadOrder()
    local mcmIndex = nil
    for i, uuid in ipairs(loadOrder) do
        if uuid == ModuleUUID then
            mcmIndex = i
            break
        end
    end
    if not mcmIndex then
        return {}
    end

    -- Get all loaded mods with an MCM blueprint
    local modsWithBlueprint = {}
    for modUUID, modData in pairs(ModConfig.mods) do
        if modData.blueprint and ModValidation:IsModRelevant(Ext.Mod.GetMod(modUUID)) then
            table.insert(modsWithBlueprint, modUUID)
        end
    end

    local violations = {}
    -- Check mods loaded before MCM
    for i = 1, mcmIndex - 1 do
        local uuid = loadOrder[i]
        if table.contains(modsWithBlueprint, uuid) then
            table.insert(violations, uuid)
        end
    end

    return violations
end

return MCMPrecedenceCheck
