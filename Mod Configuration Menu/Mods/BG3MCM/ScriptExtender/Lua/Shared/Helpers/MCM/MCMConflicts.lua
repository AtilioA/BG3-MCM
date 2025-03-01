---@class MCMConflicts
MCMConflicts = _Class:Create("MCMConflicts", nil, {})

--- Warns about load order conflicts by delegating the evaluation to ConflictCheck.
--- Any detected conflicts are logged as warnings and reported via notifications.
function MCMConflicts:WarnAboutLoadOrderConflicts()
    local issues = ConflictCheck:EvaluateLoadOrderConflicts()
    if not issues or #issues == 0 then
        return
    end

    for _, issue in ipairs(issues) do
        local conflictIssueTitle = "Conflict issue detected: " ..
            issue.modName .. " depends on " .. issue.conflictName
        NotificationManager:CreateIMGUINotification(issue.id, issue.severity, conflictIssueTitle, issue.resultMessage,
            {},
            ModuleUUID)

        MCMWarn(0, issue.resultMessage)
    end
end

return MCMConflicts
