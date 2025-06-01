-- Handles discovery and initialization of storage backends for DynamicSettings

local AdapterFactory = require("Shared/DynamicSettings/Factories/AdapterFactory")
local SettingsService = require("Shared/DynamicSettings/Services/SettingsService")

---@class StorageManager
local StorageManager = {}

--- Discover all ModVars for a specific module
---@param moduleUUID string The UUID of the module to discover variables for
local function discoverModVars(moduleUUID)
    local vars = Ext.Vars.GetModVariables(moduleUUID)
    if not vars then return end

    local count = 0
    for varName, _ in pairs(vars) do
        SettingsService.RegisterDiscoveredVariable(moduleUUID, varName, "ModVar")
        count = count + 1
    end

    if count > 0 then
        MCMDebug(2, string.format("Discovered %d ModVars for module %s", count, moduleUUID))
    end
end

--- Discover all ModConfig variables for a specific module (future functionality)
---@param moduleUUID string The UUID of the module to discover variables for
local function discoverModConfig(moduleUUID)
    -- This is a stub for future functionality
    -- When ScriptExtender adds ModConfig API, this function will be updated
    -- For now, it does nothing

    -- Future implementation will look like this:
    -- if Ext.ModConfig and Ext.ModConfig.GetModConfigVariables then
    --   local cvars = Ext.ModConfig.GetModConfigVariables(moduleUUID)
    --   if cvars then
    --     for varName, _ in pairs(cvars) do
    --       SettingsService.RegisterDiscoveredVariable(moduleUUID, varName, "ModConfig")
    --     end
    --   end
    -- end

    -- For now, just return without doing anything
    return
end

--- Initialize the storage backends and register adapters
function StorageManager.Initialize()
    -- Register all storage adapters
    AdapterFactory.Initialize()
    MCMDebug(1, "Storage adapters initialized")
end

--- Run discovery for all modules and all storage types
function StorageManager.DiscoverAllVariables()
    local moduleUUIDs = Ext.Mod.GetLoadOrder()
    local totalModules = #moduleUUIDs
    local modulesWithVars = 0

    MCMDebug(1, string.format("Starting variable discovery for %d modules", totalModules))

    for _, moduleUUID in ipairs(moduleUUIDs) do
        local hasVars = false

        -- Discover ModVars
        local modvars = Ext.Vars.GetModVariables(moduleUUID)
        local vars = {}
        for k, v in pairs(modvars) do
            vars[k] = v
        end

        if not table.isEmpty(vars) then
            discoverModVars(moduleUUID)
            hasVars = true
        end

        -- Discover ModConfig variables (if API is available)
        discoverModConfig(moduleUUID)

        if hasVars then
            modulesWithVars = modulesWithVars + 1
        end
    end

    MCMDebug(1, string.format("\n\nVariable discovery complete. Found variables in %d/%d modules",
        modulesWithVars, totalModules))
end

local function testServiceCalls()
    if MCMAPI:GetSettingValue("debug_level", ModuleUUID) >= 1 then
        _D(SettingsService.GetAll("5b5ad5b6-ce37-4a63-8dea-a1fee4cee156"))
        _D(SettingsService.Get("5b5ad5b6-ce37-4a63-8dea-a1fee4cee156", "HostOnlyCheats", "ModVar"))

        -- Change the value of a ModVar
        -- SettingsService.Set("5b5ad5b6-ce37-4a63-8dea-a1fee4cee156", "HostOnlyCheats", "ModVar", 1)
        _D(SettingsService.Get("5b5ad5b6-ce37-4a63-8dea-a1fee4cee156", "HostOnlyCheats", "ModVar"))
    end
end

--- Register event listeners for discovery
function StorageManager.RegisterEventListeners()
    -- Run discovery when a session is loading
    -- Register with the ModEventManager for session loading
    Ext.Events.SessionLoaded:Subscribe(function()
        MCMDebug(1, "SessionLoaded event received, initializing storage and discovering variables")
        StorageManager.Initialize()
        StorageManager.DiscoverAllVariables()
        testServiceCalls()
    end)

    -- Could add other listeners here for refreshing discovery, etc.
end

return StorageManager
