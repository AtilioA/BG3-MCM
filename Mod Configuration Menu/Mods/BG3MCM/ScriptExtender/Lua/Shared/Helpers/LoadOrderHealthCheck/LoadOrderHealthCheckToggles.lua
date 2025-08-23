---@class LoadOrderHealthCheckToggles
LoadOrderHealthCheckToggles = _Class:Create("LoadOrderHealthCheckToggles", nil, {})

---@param e ExtGameStateChangedEvent
function LoadOrderHealthCheckToggles:RunAllChecks(e)
    if not e or not e.ToState then return end
    if e.ToState ~= Ext.Enums.ClientGameState["Menu"] then return end

    local shouldCheckInvalidUUIDs = MCMAPI:GetSettingValue("enable_invalid_uuids_check", ModuleUUID)
    if shouldCheckInvalidUUIDs then
        LoadOrderHealthCheck:WarnAboutInvalidUUIDs()
    end

    local shouldCheckLoadOrderDependencies = MCMAPI:GetSettingValue("enable_loadorder_dependencies_check", ModuleUUID)
    if shouldCheckLoadOrderDependencies then
        LoadOrderHealthCheck:WarnAboutLoadOrderDependencies()
    end

    local shouldCheckNPAKM = MCMAPI:GetSettingValue("enable_npakm_check", ModuleUUID)
    if shouldCheckNPAKM then
        LoadOrderHealthCheck:WarnAboutNPAKM()
    end

    local shouldCheckModConflicts = MCMAPI:GetSettingValue("enable_modconflicts_check", ModuleUUID)
    if shouldCheckModConflicts then
        LoadOrderHealthCheck:WarnAboutModConflicts()
    end

    local shouldCheckMCMPrecedence = MCMAPI:GetSettingValue("enable_mcmprecedence_check", ModuleUUID)
    if shouldCheckMCMPrecedence then
        LoadOrderHealthCheck:WarnAboutMCMPrecedence()
    end
end

return LoadOrderHealthCheckToggles
