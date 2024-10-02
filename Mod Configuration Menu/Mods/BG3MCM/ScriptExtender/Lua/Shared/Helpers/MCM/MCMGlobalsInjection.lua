-- Reverse lookup table for ModuleUUID to modTable
ModUUIDToModTableName = {}

-- Utility function to populate the reverse lookup table from existing Mods
-- Thanks to LaughingLeader for this!
local function initializeReverseLookupTable(lookupTable)
    for _, modUUID in pairs(Ext.Mod.GetLoadOrder()) do
        local mod = Ext.Mod.GetMod(modUUID)
        local scriptExtenderConfigPath = string.format("Mods/%s/ScriptExtender/Config.json", mod.Info.Directory)
        local config = Ext.IO.LoadFile(scriptExtenderConfigPath, "data")
        if config ~= nil then
            local modConfig = Ext.Json.Parse(config)
            if modConfig ~= nil then
                local modTable = modConfig.ModTable
                lookupTable[mod.Info.ModuleUUID] = modTable
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

-- Function to inject MCM into the mod table
local function injectMCMToModTable(modUUID)
    if modUUID == ModuleUUID then return end

    MCMPrint(2, "Injecting MCM to mod table for modUUID: " .. modUUID)

    -- Retrieve ModTable name using the reverse lookup table
    local modTableName = getModTableNameByUUID(modUUID)
    if not modTableName then
        MCMWarn(2, "Unable to find ModTable name for modUUID: " .. modUUID)
        return
    end

    MCMPrint(1, "Mod table name: " .. modTableName)
    local modTable = Mods[modTableName]
    if not modTable then
        MCMWarn(2, "Mod table not found for modTableName: " .. modTableName)
        return
    end

    if modTable.MCM then
        MCMPrint(1, "MCM already exists in mod table for modUUID: " .. modUUID .. ". Skipping metatable injection.")
        return
    end

    local MCM = {}

    -- Define useful functions for mods to use
    MCM.Get = function(settingId)
        -- MCMDebug(1, "Getting setting value for settingId: " .. settingId)
        return MCMAPI:GetSettingValue(settingId, modUUID)
    end

    -- Return a list of enabled items from a list setting; empty table if list is disabled
    MCM.GetList = function(listSettingId)
        local setting = MCM.Get(listSettingId)

        local enabledItems = {}
        if not setting or not setting.enabled then return enabledItems end

        for _, element in ipairs(setting.elements) do
            if element.enabled then
                enabledItems[element.name] = true
            end
        end

        return enabledItems
    end

    MCM.Set = function(settingId, value)
        -- MCMDebug(1, "Setting value for settingId: " .. settingId .. " to: " .. tostring(value))
        MCMAPI:SetSettingValue(settingId, value, modUUID)
    end

    MCM.Reset = function(settingId)
        -- MCMDebug(1, "Resetting setting value for settingId: " .. settingId)
        MCMAPI:ResetSettingValue(settingId, modUUID)
    end

    modTable.MCM = MCM

    MCMSuccess(1, "Successfully injected MCM to mod table for modUUID: " .. modUUID)
end

-- Function to set up the metatable for the Mods table so that we can listen for new mods being added
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
                MCMPrint(2, "Added to reverse lookup: " .. value.ModuleUUID .. " -> " .. key)
            else
                MCMWarn(0, "Unexpected: mod '" .. tostring(key) .. "' does not have a ModuleUUID.")
            end

            -- Add MCM to mods that have an MCM blueprint
            if ModConfig.mods[value.ModuleUUID] then
                injectMCMToModTable(value.ModuleUUID)
            end
            -- Add NotificationManager to all mods
            NotificationManager:InjectNotificationManagerToModTable(value.ModuleUUID)
        end
    }

    -- Set the metatable for the Mods table only once
    if not getmetatable(Mods) then
        setmetatable(Mods, modsMetatable)
        MCMPrint(1, "Metatable for Mods table has been set.")
    else
        MCMWarn(2, "Mods table already has a metatable. Skipping metatable assignment.")
    end
end

-- Initialize the reverse lookup table with existing Config.json files
initializeReverseLookupTable(ModUUIDToModTableName)

-- Set up the metatable to handle future additions to Mods and possible MCM injection
setupModsMetatable()
