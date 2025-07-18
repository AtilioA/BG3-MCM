-- This module is responsible for checking the dependencies of all available mods.
-- It verifies if the required versions of dependencies are met and logs warnings if they are not.
-- This ensures that all mods function correctly and that users are informed of any compatibility issues.
-- No, this is not *really* related to MCM, but it is useful and it's a popular mod, so I'm including it here.


---@class DependencyCheck: _Class
---@field issues DependencyCheckResult[] A list of issues with mod dependencies
DependencyCheck = _Class:Create("DependencyCheck", nil, {})

---@class DependencyCheckResult
---@field id string
---@field severity NotificationSeverity
---@field modName string
---@field dependencyName string
---@field resultMessage string

--- Checks if the loaded version is compatible with the required version.
---@param loadedDependencyVersion vec4 The loaded mod version.
---@param requiredVersion vec4 The required mod version.
---@return boolean True if compatible, false otherwise.
local function isDependencyVersionCompatible(loadedDependencyVersion, requiredVersion)
    for i = 1, 4 do
        if loadedDependencyVersion[i] < requiredVersion[i] then
            return false
        elseif loadedDependencyVersion[i] > requiredVersion[i] then
            return true
        end
    end
    return true
end

--- Checks if the two given versions are equal.
--- @param version1 vec4 The first version.
--- @param version2 vec4 The second version.
--- @return boolean True if the versions are equal, false otherwise.
local function areVersionsEqual(version1, version2)
    for i = 1, 4 do
        if version1[i] ~= version2[i] then
            return false
        end
    end

    return true
end

--- Checks if the loaded mod version is compatible with the required dependency version.
---@param mod Module The mod that requires the dependency.
---@param dependency ModuleInfo The required dependency.
---@param loadedDependencyMod Module The loaded dependency mod.
---@param issues table The table to record issues in.
local function checkVersionCompatibility(mod, dependency, loadedDependencyMod, issues)
    local function checkIfDependencyHasVersionInfo()
        if not areVersionsEqual(loadedDependencyMod.Info.ModVersion, { 0, 0, 0, 0 }) then return false end

        local depMod = Ext.Mod.GetMod(dependency.ModuleUUIDString)
        local dependencyInfo = depMod and depMod.Info or {}

        local issueID = string.format("Dependency_Missing_Version_Info_%s_Requires_%s",
            mod.Info.ModuleUUID,
            dependency.ModuleUUIDString
        )
        local resultMessage = VCString:InterpolateLocalizedMessage(
            "h5ab91d6d4bd04b9696355aa0c34b5be63740",
            dependencyInfo.Name, mod.Info.Name, dependencyInfo.Author, dependencyInfo.Name)

        table.insert(issues, {
            id = issueID,
            modName = mod.Info.Name,
            dependencyName = dependency.Name,
            resultMessage = resultMessage,
            severity = "warning"
        })
        return true
    end

    local mainModVersion = mod.Info.ModVersion
    local loadedDependencyVersion = loadedDependencyMod.Info.ModVersion
    local requiredVersion = dependency.ModVersion

    -- Necessary due to old/broken meta.lsx
    if checkIfDependencyHasVersionInfo() then
        return
    end

    MCMDebug(3,
        string.format("Checking version compatibility for mod '%s' with dependency '%s'.", mod.Info.Name, dependency
            .Name))

    -- This is unfortunately necessary due to an MMT bug
    local versionsEqual = areVersionsEqual(mainModVersion, requiredVersion)
    local versionCompatible = isDependencyVersionCompatible(loadedDependencyVersion, requiredVersion)

    if not versionsEqual and not versionCompatible then
        local issueID = string.format("Dependency_Version_Issue_%s_Requires_%s_%s_Loaded_%s",
            mod.Info.ModuleUUID,
            dependency.ModuleUUIDString,
            requiredVersion[1] .. "." .. requiredVersion[2] .. "." .. requiredVersion[3] .. "." .. requiredVersion[4],
            loadedDependencyVersion[1] ..
            "." .. loadedDependencyVersion[2] .. "." .. loadedDependencyVersion[3] .. "." .. loadedDependencyVersion[4]
        )
        local requiredVersionStr = table.concat(requiredVersion, ".")
        local loadedVersionStr = table.concat(loadedDependencyVersion, ".")
        local resultMessage = VCString:InterpolateLocalizedMessage(
            "h1c39894da62148389dbf1bddaf761a4bf56f",
            mod.Info.Name, dependency.Name, requiredVersionStr, loadedVersionStr)
        table.insert(issues, {
            id = issueID,
            modName = mod.Info.Name,
            dependencyName = dependency.Name,
            resultMessage = resultMessage,
            severity = "error"
        })
    end
end

--- Records an issue for a missing dependency.
---@param mod Module The mod that requires the dependency.
---@param dependency ModuleInfo The missing dependency.
---@param issues table The table to record issues in.
local function recordMissingDependency(mod, dependency, issues)
    local issueID = string.format("Missing_Dependency_%s_Requires_%s",
        mod.Info.ModuleUUID,
        dependency.ModuleUUIDString
    )
    local resultMessage = VCString:InterpolateLocalizedMessage(
        "h81ddeda4ecc14ac3a2c27dbaaea487be2ge7", mod.Info.Name, dependency.Name)
    MCMWarn(1, "Missing dependency recorded: " .. resultMessage)
    table.insert(issues, {
        id = issueID,
        modName = mod.Info.Name,
        dependencyName = dependency.Name,
        resultMessage = resultMessage,
        severity = "error"
    })
end

--- Checks the dependencies of a mod and records any issues.
---@param mod Module The mod to check dependencies for.
---@param dependency ModuleInfo The list of dependencies to check.
---@param issues table The table to record issues in.
local function checkDependency(mod, dependency, issues)
    -- Ignore the dependency if it is listed in the ignored mods
    local ignoredMods = IgnoredModDependencies.Mods
    local ignoredMod = ignoredMods[dependency.ModuleUUIDString]
    if ignoredMod then
        MCMDebug(2,
            string.format("Ignoring dependency '%s' for mod '%s' as it is listed in ignored mods | Reason: %s.",
                dependency.Name, mod.Info.Name, ignoredMod.Reason))
        return
    end

    local loadedDependencyMod = Ext.Mod.GetMod(dependency.ModuleUUIDString)

    if not loadedDependencyMod then
        recordMissingDependency(mod, dependency, issues)
    else
        checkVersionCompatibility(mod, dependency, loadedDependencyMod, issues)
    end
end

---@param mod Module The mod to check dependencies for.
---@param dependencies ModuleInfo The list of dependencies to check.
---@param issues table The table to record issues in.
local function checkModDependencies(mod, dependencies, issues)
    for _, dependency in ipairs(dependencies) do
        checkDependency(mod, dependency, issues)
    end
end

--- Checks mod dependencies and returns a list of issues.
---@return DependencyCheckResult[] issues A list of issues with mod dependencies.
function DependencyCheck:EvaluateLoadOrderDependencies()
    local success = false
    local issues = {}

    success, issues = xpcall(function()
        local availableMods = Ext.Mod.GetModManager() and Ext.Mod.GetModManager().AvailableMods or {}

        MCMPrint(1, "Evaluating load order dependencies for available mods.")
        for _, mod in ipairs(availableMods) do
            if ModValidation:IsModRelevant(mod) and mod.Dependencies then
                checkModDependencies(mod, mod.Dependencies, issues)
            end
        end

        MCMPrint(1, "Dependency evaluation complete. Issues found: " .. #issues)
        return issues
    end, function(e)
        MCMError(0, "Error evaluating load order dependencies: " .. e)
        return {}
    end)

    if not success then
        MCMError(0, "Error evaluating load order dependencies.")
    end

    return issues
end

return DependencyCheck
