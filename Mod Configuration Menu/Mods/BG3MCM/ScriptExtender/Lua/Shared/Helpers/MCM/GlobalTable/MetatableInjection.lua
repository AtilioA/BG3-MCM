-- Handles the metatable setup for the Mods table to listen for new mods being added

local TableInjector = Ext.Require("Shared/Helpers/MCM/GlobalTable/TableInjector.lua")

-- Reverse lookup table for ModuleUUID to modTable
ModUUIDToModTableName = {}

-- Utility function to populate the reverse lookup table from existing Mods
-- Thanks to LaughingLeader for this!
local function initializeReverseLookupTable(lookupTable)
    for _, modUUID in pairs(Ext.Mod.GetLoadOrder()) do
        local mod = Ext.Mod.GetMod(modUUID)
        local scriptExtenderConfigPath = string.format("Mods/%s/ScriptExtender/Config.json", mod.Info.Directory)
        local config = Ext.IO.LoadFile(scriptExtenderConfigPath, "data")
        if config then
            local modConfig = Ext.Json.Parse(config)
            if modConfig then
                lookupTable[mod.Info.ModuleUUID] = modConfig.ModTable
            end
        else
            MCMWarn(3, string.format("No config for %s at %s", mod.Info.Name, scriptExtenderConfigPath))
        end
    end
end

-- Utility function to get ModTable name by ModuleUUID using reverse lookup
---@param modUUID GUIDSTRING The UUID of the mod
---@return string ModTable - The ModTable key string in the Mods table for the given modUUID
local function getModTableNameByUUID(modUUID)
    return ModUUIDToModTableName[modUUID]
end

-- Helper: Get and validate the mod table for a given modUUID.
---@param modUUID GUIDSTRING The UUID of the mod
---@return table|nil modTable The mod table or nil if not found
---@return string|nil modTableName The name of the mod table or nil if not found
local function getModTableForUUID(modUUID)
    local modTableName = getModTableNameByUUID(modUUID)
    if not modTableName then
        MCMWarn(1, "Unable to find ModTable name for modUUID: " .. modUUID)
        return nil
    end

    local modTable = Mods[modTableName]
    if not modTable then
        MCMWarn(2, "Mod table not found for modTableName: " .. modTableName)
        return nil
    end
    return modTable, modTableName
end

-- Set up the metatable for the Mods table so that we can listen for new mods being added
local function setupModsMetatable()
    -- Define a custom __newindex function to listen for new entries in the Mods table
    local modsMetatable = {
        __newindex = function(table, key, value)
            MCMDebug(2, "New mod being added to Mods table: " .. tostring(key))

            -- Set the new key-value pair in the table as normal
            rawset(table, key, value)

            if value.ModuleUUID then
                -- Update the reverse lookup table
                ModUUIDToModTableName[value.ModuleUUID] = key
                MCMPrint(2,
                    "Added to reverse lookup: " ..
                    value.ModuleUUID .. " -> " .. key .. " (" .. Ext.Mod.GetMod(value.ModuleUUID).Info.Name .. ")")

                -- Inject MCM for all mods and always inject the NotificationManager.
                TableInjector.injectMCMToModTable(value.ModuleUUID)
                NotificationManager:InjectNotificationManagerToModTable(value.ModuleUUID)
            else
                MCMWarn(0, "Unexpected: mod '" .. tostring(key) .. "' does not have a ModuleUUID.")
            end
        end
    }

    if not getmetatable(Mods) then
        setmetatable(Mods, modsMetatable)
        MCMPrint(1, "Metatable for Mods table has been set.")
    else
        MCMWarn(2, "Mods table already has a metatable. Skipping metatable assignment.")
    end
end

-- Public API
local MetatableInjection = {
    initializeReverseLookupTable = initializeReverseLookupTable,
    getModTableNameByUUID = getModTableNameByUUID,
    getModTableForUUID = getModTableForUUID,
    setupModsMetatable = setupModsMetatable
}

return MetatableInjection
