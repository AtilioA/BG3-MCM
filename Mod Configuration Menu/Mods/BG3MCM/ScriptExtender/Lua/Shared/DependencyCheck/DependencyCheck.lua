-- This module is responsible for checking the dependencies of all available mods.
-- It verifies if the required versions of dependencies are met and logs warnings if they are not.
-- This ensures that all mods function correctly and that users are informed of any compatibility issues.
-- No, this is not *really* related to MCM, but it is useful and it's a popular mod, so I'm including it here.


---@class DependencyCheck: _Class
---@field issues DependencyCheckResult[] A list of issues with mod dependencies
DependencyCheck = _Class:Create("DependencyCheck", nil, {})

---@class DependencyCheckResult
---@field modName string
---@field dependencyName string
---@field errorMessage string

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
        if areVersionsEqual(loadedDependencyMod.Info.ModVersion, { 0, 0, 0, 0 }) then
            MCMWarn(1,
                string.format("Ignoring dependency '%s' for mod '%s' since it has no version information.", dependency.Name, mod.Info.Name))
            return true
        end
        return false
    end

    local mainModVersion = mod.Info.ModVersion
    local loadedDependencyVersion = loadedDependencyMod.Info.ModVersion
    local requiredVersion = dependency.ModVersion


    -- Necessary due to a SE bug
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
        local errorMessage = string.format(
            "Mod '%s' requires '%s' version %d.%d.%d.%d or higher, but loaded version is %d.%d.%d.%d\nPlease update %s.",
            mod.Info.Name, dependency.Name,
            requiredVersion[1], requiredVersion[2], requiredVersion[3], requiredVersion[4],
            loadedDependencyVersion[1], loadedDependencyVersion[2], loadedDependencyVersion[3],
            loadedDependencyVersion[4], dependency.Name
        )
        table.insert(issues, {
            modName = mod.Info.Name,
            dependencyName = dependency.Name,
            errorMessage = errorMessage
        })
    end
end

--- Records an issue for a missing dependency.
---@param mod Module The mod that requires the dependency.
---@param dependency ModuleInfo The missing dependency.
---@param issues table The table to record issues in.
local function recordMissingDependency(mod, dependency, issues)
    local errorMessage = string.format("Mod '%s' requires dependency '%s', which is not loaded.\nPlease install %s.",
        mod.Info.Name,
        dependency.Name, dependency.Name)
    MCMWarn(1, "Missing dependency recorded: " .. errorMessage)
    table.insert(issues, {
        modName = mod.Info.Name,
        dependencyName = dependency.Name,
        errorMessage = errorMessage
    })
end

--- Checks the dependencies of a mod and records any issues.
---@param mod Module The mod to check dependencies for.
---@param dependencies ModuleInfo The list of dependencies to check.
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

local function checkModDependencies(mod, dependencies, issues)
    for _, dependency in ipairs(dependencies) do
        checkDependency(mod, dependency, issues)
    end
end

-- ... existing code ...

--- Checks mod dependencies and returns a list of issues.
---@return DependencyCheckResult[] issues A list of issues with mod dependencies.
function DependencyCheck:EvaluateLoadOrderDependencies()
    local issues = {}
    local availableMods = Ext.Mod.GetModManager().AvailableMods

    MCMDebug(1, "Evaluating load order dependencies for available mods.")
    for _, mod in ipairs(availableMods) do
        if Ext.Mod.IsModLoaded(mod.Info.ModuleUUID) and mod.Info.Author ~= "" and mod.Info.Author ~= "LS" and mod.Dependencies then
            checkModDependencies(mod, mod.Dependencies, issues)
        end
    end

    MCMDebug(1, "Dependency evaluation complete. Issues found: " .. #issues)
    return issues
end

return DependencyCheck