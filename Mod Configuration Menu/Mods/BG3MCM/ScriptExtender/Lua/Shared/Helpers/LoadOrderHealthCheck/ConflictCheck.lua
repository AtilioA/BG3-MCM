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

-- Special case handling for MCM conflicts with NPAKM variants
local function isNPAKMConflict(modUUID, conflictUUID)
    if modUUID ~= ModuleUUID then return false end

    -- UUIDs for No Press Any Key Menu variants that conflict with MCM
    local MCM_CONFLICTS_NPAKM_UUIDS = {
        ["2bae5aa8-bf6a-d196-069c-4269f71d22a3"] = true, -- Original NPAKM
        ["8c417ab1-195a-2c2a-abbf-70a2da9166da"] = true  -- 'PTSD' version
    }

    -- Check if the conflict is a NPAKM variant
    return MCM_CONFLICTS_NPAKM_UUIDS[conflictUUID]
end

-- Checks a single conflict entry for a mod.
local function checkConflict(mod, conflict, issues)
    local conflictingMod = Ext.Mod.GetMod(conflict.ModuleUUIDString)
    if conflictingMod then
        -- Skip generic conflict detection for NPAKM-related conflicts
        if isNPAKMConflict(mod.Info.ModuleUUID, conflict.ModuleUUIDString) then
            return
        end

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
        MCMWarn(0, "Conflict detected: " .. resultMessage)
    end
end

-- Iterates over each conflict entry in a mod.
local function checkModConflicts(mod, conflicts, issues)
    for _, conflict in ipairs(conflicts) do
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
---@return ConflictCheckResult[] issues A list of issues with mod conflicts.
function ConflictCheck:EvaluateLoadOrderConflicts()
    local success = false
    local issues = {}

    success, issues = xpcall(function()
        local availableMods = Ext.Mod.GetModManager() and Ext.Mod.GetModManager().AvailableMods or {}

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

    return issues
end

return ConflictCheck
