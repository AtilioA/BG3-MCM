---@class LoadOrderHealthCheckToggles
LoadOrderHealthCheckToggles = _Class:Create("LoadOrderHealthCheckToggles", nil, {})

--- Run enabled checks independently so one failed diagnostic does not skip the others.
---@return nil
function LoadOrderHealthCheckToggles:RunAllChecks()
    if not MCMUtils.IsClientMainMenu() then
        return
    end

    local checks = {
        { settingId = "enable_invalid_meta_check", run = LoadOrderHealthCheck.WarnAboutInvalidUUIDs },
        { settingId = "enable_loadorder_dependencies_check", run = LoadOrderHealthCheck.WarnAboutLoadOrderDependencies },
        { settingId = "enable_npakm_check", run = LoadOrderHealthCheck.WarnAboutNPAKM },
        { settingId = "enable_modconflicts_check", run = LoadOrderHealthCheck.WarnAboutModConflicts },
        { settingId = "enable_mcmprecedence_check", run = LoadOrderHealthCheck.WarnAboutMCMPrecedence },
    }
    for _, check in ipairs(checks) do
        if MCMAPI:GetSettingValue(check.settingId, ModuleUUID) then
            local success, err = xpcall(function()
                check.run(LoadOrderHealthCheck)
            end, debug.traceback)
            if not success then
                MCMError(0, "Load-order check '%s' failed: %s", check.settingId, err)
            end
        end
    end
end

return LoadOrderHealthCheckToggles
