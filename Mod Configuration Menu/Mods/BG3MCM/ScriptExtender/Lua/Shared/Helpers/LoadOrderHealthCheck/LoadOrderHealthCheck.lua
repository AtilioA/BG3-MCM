---@class LoadOrderHealthCheck
---@field NPAKMWarned boolean
LoadOrderHealthCheck = _Class:Create("LoadOrderHealthCheck", nil, {
    NPAKMWarned = false
})

-- Checks if a compatibility warning for "No Press Any Key Menu" should be shown.
function LoadOrderHealthCheck:ShouldWarnAboutNPAKM()
    local NoPressAnyKeyMenuUUID     = "2bae5aa8-bf6a-d196-069c-4269f71d22a3"
    local NoPressAnyKeyMenuMCMUUID  = "eb263453-0cc2-4f0c-2375-f4e0f60e8a12"
    local NoPressAnyKeyMenuPTSDUUID = "8c417ab1-195a-2c2a-abbf-70a2da9166da"

    if Ext.Mod.IsModLoaded(NoPressAnyKeyMenuUUID) or Ext.Mod.IsModLoaded(NoPressAnyKeyMenuPTSDUUID) then
        return true
    end

    -- Also double-check with the MCM-specific version, in case it's loaded instead.
    if Ext.Mod.IsModLoaded(NoPressAnyKeyMenuMCMUUID) then
        return false
    end
end

-- Creates a notification for missing NPAKM compatibility patch.
function LoadOrderHealthCheck:CreateNPAKMIMGUIWarning()
    if not self.NPAKMWarned then
        local id = "NPAKM_MCM_Compatibility_Patch_Missing"
        NotificationManager:CreateIMGUINotification(
            id,
            'error',
            "Wrong No Press Any Key Menu version",
            "You're using 'No Press Any Key Menu' without the MCM compatibility patch.\n" ..
            "Your main menu may not display the MCM button correctly.\n\n" ..
            "Please replace it with the patched version from Caites' mod page.",
            {},
            ModuleUUID
        )
        self.NPAKMWarned = true
    end
end

-- Checks whether to warn about NPAKM and, if so, creates an IMGUI notification and logs a warning.
function LoadOrderHealthCheck:WarnAboutNPAKM()
    if not self:ShouldWarnAboutNPAKM() then
        return
    end

    self:CreateNPAKMIMGUIWarning()
    MCMWarn(0, "You're using 'No Press Any Key Menu' without the compatibility patch for MCM. " ..
        "Please replace it with the patched version available at its mod page.")
end

-- Evaluates load order dependencies (via DependencyCheck) and shows notifications for any issues.
function LoadOrderHealthCheck:WarnAboutLoadOrderDependencies()
    local issues = DependencyCheck:EvaluateLoadOrderDependencies()
    for _, issue in ipairs(issues) do
        local dependencyIssueTitle = "Dependency issue detected: " ..
            issue.modName .. " depends on " .. issue.dependencyName

        NotificationManager:CreateIMGUINotification(
            issue.id,
            issue.severity,
            dependencyIssueTitle,
            issue.resultMessage,
            { dontShowAgainButton = true },
            ModuleUUID
        )

        MCMWarn(0, issue.resultMessage)
    end
end

-- Scans for mods with a "null" UUID (00000000-0000-0000-0000-000000000000) and warns the user.
function LoadOrderHealthCheck:WarnAboutInvalidUUIDs()
    local invalidMods = InvalidMods:GetInvalidMods()

    -- Show a notification for each invalid mod found
    for _, mod in ipairs(invalidMods) do
        local invalidModVersion = table.concat(mod.Info.ModVersion, ".")
        local modName           = mod.Info.Name or "Unknown"
        local title             = string.format("Your load order has a mod with an invalid UUID (%s %s)", modName,
            invalidModVersion)
        local message           = string.format(
            "Mod '%s' has an invalid UUID (%s).\nThis mod will prevent your load order from loading properly.\nPlease delete the pak file for this mod or look for an update.\nYou may downgrade to Patch 6 and use Mod Uninstaller to try to remove this mod if you can't load a save without this mod.",
            modName,
            mod.Info.ModuleUUID or mod.Info.ModuleUUIDString
        )

        NotificationManager:CreateIMGUINotification(
            "InvalidUUID_" .. modName,
            'error',
            title,
            message,
            { dontShowAgainButton = true },
            ModuleUUID
        )

        MCMWarn(0, message)
    end
end

-- Example function that creates one notification of each severity level.
function LoadOrderHealthCheck:CreateNotificationForEachLevel()
    -- Info
    local infoId = "MCM_Dependency_Info"
    local infoOptions = {
        dontShowAgainButton = (math.random(0, 1) == 1),
        dontShowAgainButtonCountdownInSec = math.random(2, 7),
        buttons = {
            ["More Info"] = function()
                NotificationManager:CreateIMGUINotification(
                    "Info_More_Info",
                    'info',
                    "More Info",
                    "Here is more information about the notification.",
                    {},
                    ModuleUUID
                )
            end,
            ["View Details"] = function()
                NotificationManager:CreateIMGUINotification(
                    "Success_View_Details",
                    'success',
                    "Details",
                    "Here are the details of the success notification.",
                    {},
                    ModuleUUID
                )
            end,
        }
    }
    NotificationManager:CreateIMGUINotification(
        infoId,
        'info',
        "Information",
        "This is an informational notification.",
        infoOptions,
        ModuleUUID
    )

    -- Success
    local successId = "MCM_Dependency_Success"
    local successOptions = {
        duration = math.random(2, 10),
        dontShowAgainButton = (math.random(0, 1) == 1),
        dontShowAgainButtonCountdownInSec = math.random(2, 7),
    }
    NotificationManager:CreateIMGUINotification(
        successId,
        'success',
        "Success",
        "This is a success notification.",
        successOptions,
        ModuleUUID
    )

    -- Warning
    local warningId = "MCM_Dependency_Warning"
    local warningOptions = {
        duration = math.random(2, 10),
        dontShowAgainButton = (math.random(0, 1) == 1),
        dontShowAgainButtonCountdownInSec = math.random(2, 7),
        buttons = {
            ["Take Action"] = function()
                NotificationManager:CreateIMGUINotification(
                    "Warning_Take_Action",
                    'warning',
                    "Action Required",
                    "Please take action regarding this warning.",
                    {},
                    ModuleUUID
                )
            end
        }
    }
    NotificationManager:CreateIMGUINotification(
        warningId,
        'warning',
        "Warning",
        "This is a warning notification.",
        warningOptions,
        ModuleUUID
    )

    -- Error
    local errorId = "MCM_Dependency_Error"
    local errorOptions = {
        duration = math.random(2, 10),
        dontShowAgainButton = true,
        dontShowAgainButtonCountdownInSec = math.random(2, 7),
        buttons = {
            ["Retry"] = function()
                MCMDebug(1, "Retrying the operation related to the error.")
            end,
        }
    }
    NotificationManager:CreateIMGUINotification(
        errorId,
        'error',
        "Error",
        "This is an error notification.",
        errorOptions,
        ModuleUUID
    )
end

return LoadOrderHealthCheck
