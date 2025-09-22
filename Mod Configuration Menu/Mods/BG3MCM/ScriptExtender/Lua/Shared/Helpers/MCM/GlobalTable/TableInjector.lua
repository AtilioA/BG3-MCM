-- Handles the creation and injection of the MCM table into mod tables

local MCMAPIMethods = Ext.Require("Shared/Helpers/MCM/GlobalTable/MCMAPIMethods.lua")
local MetatableInjection = nil

-- Ensure that the mod's MCM table exists and attach common functions.
---@param modTable table The mod table to inject the MCM table into
---@param originalModUUID GUIDSTRING The UUID of the mod
---@return table MCMInstance The injected MCM table
local function injectSharedMCMTable(modTable, originalModUUID)
    if not modTable.MCM or table.isEmpty(modTable.MCM) then
        modTable.MCM = {}
    end

    local MCMInstance = MCMAPIMethods.createMCMAPIMethods(originalModUUID)

    -- Apply the methods to the mod's MCM table
    for key, value in pairs(MCMInstance) do
        modTable.MCM[key] = value
    end

    return modTable.MCM
end


-- Expose MCM API methods in the BG3MCM global table
---@param mcmTable table The MCM table with API methods to expose
local function exposeMCMInGlobals(mcmTable)
    if not _G.Mods or not _G.Mods.BG3MCM then return end

    -- Copy all MCM API methods to Mods.BG3MCM
    for key, value in pairs(mcmTable) do
        if type(value) == "function" then
            _G.Mods.BG3MCM[key] = value
        end
    end

    -- Handle nested tables like MCM.List, MCM.EventButton, etc.
    local function copyNestedTables(source, target)
        for k, v in pairs(source) do
            if type(v) == "table" and not target[k] then
                target[k] = {}
                copyNestedTables(v, target[k])
            elseif type(v) == "function" and not target[k] then
                target[k] = v
            end
        end
    end

    copyNestedTables(mcmTable, _G.Mods.BG3MCM)
end

-- Main function to inject MCM into the mod table
---@param originalModUUID GUIDSTRING The UUID of the mod to inject MCM into
local function injectMCMToModTable(originalModUUID)
    -- Ensure MetatableInjection is loaded
    if not MetatableInjection then
        MetatableInjection = Ext.Require("Shared/Helpers/MCM/GlobalTable/MetatableInjection.lua")
    end

    MCMPrint(2,
        "Injecting MCM to mod table for modUUID: " ..
        originalModUUID .. " (" .. Ext.Mod.GetMod(originalModUUID).Info.Name .. ")")

    local modTable, modTableName = MetatableInjection.getModTableForUUID(originalModUUID)
    if not modTable then return end

    MCMPrint(2, "Mod table name: " .. modTableName)
    local MCMInstance = injectSharedMCMTable(modTable, originalModUUID)
    MCMAPIMethods.createMCMAPIMethods(originalModUUID, modTable)

    modTable.MCM = MCMInstance

    MCMSuccess(1, "Successfully injected MCM to mod table for modUUID: " .. originalModUUID)
end

-- Initialize the MCM table injection system
function Initialize()
    -- Ensure MetatableInjection is loaded
    if not MetatableInjection then
        MetatableInjection = Ext.Require("Shared/Helpers/MCM/GlobalTable/MetatableInjection.lua")
    end

    -- Expose the BG3MCM API in the global table as well for console purposes
    local bg3mcmInstance = MCMAPIMethods.createMCMAPIMethods(ModuleUUID)
    exposeMCMInGlobals(bg3mcmInstance)

    -- Initialize the reverse lookup table with existing Config.json files
    MetatableInjection.initializeReverseLookupTable(ModUUIDToModTableName)

    -- Set up the metatable to handle future additions to Mods and possible MCM injection
    MetatableInjection.setupModsMetatable()

    MCMPrint(1, "MCM Table Injector initialized successfully")
end

-- Public API
local TableInjector = {
    injectSharedMCMTable = injectSharedMCMTable,
    injectMCMToModTable = injectMCMToModTable,
    Initialize = Initialize
}

return TableInjector
