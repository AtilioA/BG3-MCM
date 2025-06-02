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

-- Main function to inject MCM into the mod table
---@param originalModUUID GUIDSTRING The UUID of the mod to inject MCM into
local function injectMCMToModTable(originalModUUID)
    if originalModUUID == ModuleUUID then return end

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
    MCMAPIMethods.createClientAPIMethods(originalModUUID, modTable)

    modTable.MCM = MCMInstance
    MCMSuccess(1, "Successfully injected MCM to mod table for modUUID: " .. originalModUUID)
end

-- Initialize the MCM table injection system
function Initialize()
    -- Ensure MetatableInjection is loaded
    if not MetatableInjection then
        MetatableInjection = Ext.Require("Shared/Helpers/MCM/GlobalTable/MetatableInjection.lua")
    end

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
