MCMDependencies = {}

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
        IMGUIWarningWindow:new(id, 0, "Wrong No Press Any Key Menu version",
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
        if NotificationPreferences:ShouldShowNotification(issue.id) then
            local dependencyIssueTitle = "Dependency issue detected: " ..
                issue.modName .. " depends on " .. issue.dependencyName
            self:CreateIMGUIWarning(issue.id, 0, dependencyIssueTitle, issue.errorMessage)
            MCMWarn(0, issue.errorMessage)
        end
    end
end
