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
---@param loadedVersion vec4 The loaded mod version.
---@param requiredVersion vec4 The required mod version.
---@return boolean True if compatible, false otherwise.
local function isVersionCompatible(loadedVersion, requiredVersion)
    for i = 1, 4 do
        if loadedVersion[i] < requiredVersion[i] then
            return false
        elseif loadedVersion[i] > requiredVersion[i] then
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
---@param loadedMod Module The loaded dependency mod.
---@param issues table The table to record issues in.
local function checkVersionCompatibility(mod, dependency, loadedMod, issues)
    local mainModVersion = mod.Info.ModVersion
    local loadedVersion = loadedMod.Info.ModVersion
    local requiredVersion = dependency.ModVersion

    MCMDebug(3,
        string.format("Checking version compatibility for mod '%s' with dependency '%s'.", mod.Info.Name, dependency
            .Name))


    -- This is unfortunately necessary due to an MMT bug
    local versionsEqual = areVersionsEqual(mainModVersion, requiredVersion)
    local versionCompatible = isVersionCompatible(loadedVersion, requiredVersion)

    if not versionsEqual and not versionCompatible then
        local errorMessage = string.format(
            "Mod '%s' requires '%s' version %d.%d.%d.%d or higher, but loaded version is %d.%d.%d.%d\nPlease update %s.",
            mod.Info.Name, dependency.Name,
            requiredVersion[1], requiredVersion[2], requiredVersion[3], requiredVersion[4],
            loadedVersion[1], loadedVersion[2], loadedVersion[3], loadedVersion[4], dependency.Name
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
    local errorMessage = string.format("Mod '%s' requires dependency '%s', but it is not loaded.", mod.Info.Name,
        dependency.Name)
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
local function checkDependencies(mod, dependencies, issues)
    for _, dependency in ipairs(dependencies) do
        local loadedMod = Ext.Mod.GetMod(dependency.ModuleUUIDString)

        if not loadedMod then
            recordMissingDependency(mod, dependency, issues)
        else
            checkVersionCompatibility(mod, dependency, loadedMod, issues)
        end
    end
end

--- Checks mod dependencies and returns a list of issues.
---@return DependencyCheckResult[] issues A list of issues with mod dependencies.
function DependencyCheck:EvaluateLoadOrderDependencies()
    local issues = {}
    local availableMods = Ext.Mod.GetModManager().AvailableMods

    MCMDebug(1, "Evaluating load order dependencies for available mods.")
    for _, mod in ipairs(availableMods) do
        if mod.Info.Author ~= "" and mod.Info.Author ~= "LS" and mod.Dependencies then
            checkDependencies(mod, mod.Dependencies, issues)
        end
    end

    MCMDebug(1, "Dependency evaluation complete. Issues found: " .. #issues)
    return issues
end

return DependencyCheck
