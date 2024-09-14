---@class MCMDependencies
---@field NPAKMWarned boolean
MCMDependencies = _Class:Create("MCMDependencies", nil, {
    NPAKMWarned = false
})

function MCMDependencies:ShouldWarnAboutNPAKM()
    local NoPressAnyKeyMenuUUID = "2bae5aa8-bf6a-d196-069c-4269f71d22a3"
    local NoPressAnyKeyMenuMCMUUID = "eb263453-0cc2-4f0c-2375-f4e0f60e8a12"
    local NoPressAnyKeyMenuPTSDUUID = "8c417ab1-195a-2c2a-abbf-70a2da9166da"

    if Ext.Mod.IsModLoaded(NoPressAnyKeyMenuUUID) or Ext.Mod.IsModLoaded(NoPressAnyKeyMenuPTSDUUID) then
        return true
    end

    -- Also double check, because with inactive mods you never know
    if Ext.Mod.IsModLoaded(NoPressAnyKeyMenuMCMUUID) then
        return false
    end
end

function MCMDependencies:CreateNPAKMIMGUIWarning()
    if not self.NPAKMWarned then
        local id = "NPAKM_MCM_Compatibility_Patch_Missing"
        NotificationManager:CreateIMGUINotification(id, 'error', "Wrong No Press Any Key Menu version",
            "You're using 'No Press Any Key Menu' without the MCM compatibility patch.\nYour main menu may not work correctly.\n\nPlease replace it with the patched version from Caites' mod page.")
        self.NPAKMWarned = true
    end
end

function MCMDependencies:WarnAboutNPAKM()
    if not self:ShouldWarnAboutNPAKM() then
        return
    end

    self:CreateNPAKMIMGUIWarning()
    MCMWarn(0,
        "You're using 'No Press Any Key Menu' without the compatibility patch for MCM. Please replace it with the patched version available at its mod page.")
end

function MCMDependencies:WarnAboutLoadOrderDependencies()
    local issues = DependencyCheck:EvaluateLoadOrderDependencies()
    for _, issue in ipairs(issues) do
        local dependencyIssueTitle = "Dependency issue detected: " ..
            issue.modName .. " depends on " .. issue.dependencyName
        NotificationManager:CreateIMGUINotification(issue.id, 'error', dependencyIssueTitle, issue.errorMessage)
        MCMWarn(0, issue.errorMessage)
    end
end

-- function MCMDependencies:CreateNotificationForEachLevel()
--     -- Info level notification
--     local infoId = "MCM_Dependency_Info"
--     NotificationManager:CreateIMGUINotification(infoId, 'info', "Information", "This is an informational notification.")

--     -- Success level notification
--     local successId = "MCM_Dependency_Success"
--     NotificationManager:CreateIMGUINotification(successId, 'success', "Success", "This is a success notification.")

--     -- Warning level notification
--     local warningId = "MCM_Dependency_Warning"
--     NotificationManager:CreateIMGUINotification(warningId, 'warning', "Warning", "This is a warning notification.")

--     -- Error level notification
--     local errorId = "MCM_Dependency_Error"
--     NotificationManager:CreateIMGUINotification(errorId, 'error', "Error", "This is an error notification.")
-- end

-- MCMDependencies:CreateNotificationForEachLevel()
