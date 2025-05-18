-- This module checks for load order conflicts between mods.
-- It verifies if any mods that a given mod declares as conflicting are loaded, logging warnings if they are.
-- This ensures that users are informed of any potential compatibility issues with their mods.

---@class ConflictCheck: _Class
---@field issues ConflictCheckResult[] A list of issues with mod conflicts
ConflictCheck = _Class:Create("ConflictCheck", nil, {})

---@class ConflictCheckResult
---@field id string
---@field severity NotificationSeverity
---@field modName string
---@field conflictName string
---@field resultMessage string

-- Checks a single conflict entry for a mod.
local function checkConflict(mod, conflict, issues)
    local conflictingMod = Ext.Mod.GetMod(conflict.ModuleUUIDString)
    if conflictingMod then
        local issueID = string.format("Conflict_%s_With_%s", mod.Info.ModuleUUID, conflict.ModuleUUIDString)
        local resultMessage = VCString:InterpolateLocalizedMessage(
            "h729585d6g09c1g48cfg8290ga2e761cc46bf", mod.Info.Name, conflict.Name)
        table.insert(issues, {
            id = issueID,
            modName = mod.Info.Name,
            conflictName = conflict.Name,
            resultMessage = resultMessage,
            severity = "error"
        })
        MCMError(0, "Conflict detected: " .. resultMessage)
    end
end

-- Iterates over each conflict entry in a mod.
local function checkModConflicts(mod, conflicts, issues)
    for _, conflict in ipairs(conflicts) do
        _D(conflicts)
        checkConflict(mod, conflict, issues)
    end
end

-- Determines if a mod is valid for conflict checking.
local function isValidModForConflicts(mod)
    return mod
        and mod.Info
        and mod.Info.ModuleUUID
        and Ext.Mod.IsModLoaded(mod.Info.ModuleUUID)
        and mod.Info.Author ~= ""
        and mod.Info.Author ~= "LS"
        and mod.ModConflicts
end

--- Warns about load order conflicts.
--- This method iterates over all available mods, checks for conflicts, and logs warnings.
function ConflictCheck:EvaluateLoadOrderConflicts()
    local success, issues = xpcall(function()
        local issues = {}
        local availableMods = (Ext.Mod.GetModManager() and Ext.Mod.GetModManager().AvailableMods) or {}
        MCMDebug(1, "Evaluating load order conflicts for available mods.")
        for _, mod in ipairs(availableMods) do
            if isValidModForConflicts(mod) then
                checkModConflicts(mod, mod.ModConflicts, issues)
            end
        end
        MCMDebug(1, "Conflict evaluation complete. Issues found: " .. #issues)
        return issues
    end, function(e)
        MCMError(0, "Error evaluating load order conflicts: " .. e)
        return {}
    end)

    if not success then
        MCMError(0, "Error evaluating load order conflicts.")
    end

    for _, issue in ipairs(issues) do
        MCMWarn(1, issue.resultMessage)
    end
end

return ConflictCheck
