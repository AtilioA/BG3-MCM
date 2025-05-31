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

-- Ensure that the mod's MCM table exists and attach common functions.
-- REFACTOR: extract functions to proper API file (MCMAPI/MCMServer)
local function injectSharedMCMTable(modTable, originalModUUID)
    if not modTable.MCM or table.isEmpty(modTable.MCM) then
        modTable.MCM = {}
    end
    local MCMInstance = modTable.MCM

    -- Core API functions

    --- Get the value of a setting
    ---@param settingId string The ID of the setting to retrieve
    ---@param modUUID? GUIDSTRING Optional mod UUID, defaults to current mod
    ---@return any The value of the setting, or nil if not found
    MCMInstance.Get = function(settingId, modUUID)
        if not modUUID then modUUID = originalModUUID end
        return MCMAPI:GetSettingValue(settingId, modUUID)
    end

    --- Set the value of a setting
    ---@param settingId string The ID of the setting to set
    ---@param value any The value to set
    ---@param modUUID? GUIDSTRING Optional mod UUID, defaults to current mod
    ---@param shouldEmitEvent? boolean Whether to emit a setting changed event
    ---@return boolean success True if the setting was successfully updated
    MCMInstance.Set = function(settingId, value, modUUID, shouldEmitEvent)
        if not modUUID then modUUID = originalModUUID end
        return MCMAPI:SetSettingValue(settingId, value, modUUID, shouldEmitEvent)
    end

    -- Keybindings API
    MCMInstance.Keybindings = {
        --- Get a human-readable string representation of a keybinding
        ---@param settingId string The ID of the keybinding setting
        ---@param modUUID? GUIDSTRING Optional mod UUID, defaults to current mod
        ---@return string The formatted keybinding string (e.g., "[Ctrl] + [C]")
        Get = function(settingId, modUUID)
            if not modUUID then modUUID = originalModUUID end
            return KeyPresentationMapping:GetViewKeyForSetting(settingId, modUUID)
        end,

        --- Get the raw keybinding data
        ---@param settingId string The ID of the keybinding setting
        ---@param modUUID? GUIDSTRING Optional mod UUID, defaults to current mod
        ---@return table|nil The raw keybinding data structure or nil if not found
        GetRaw = function(settingId, modUUID)
            if not modUUID then modUUID = originalModUUID end
            return MCMAPI:GetSettingValue(settingId, modUUID)
        end
    }

    -- List API
    MCMInstance.List = {
        --- Get a table of enabled items in a list setting
        ---@param listSettingId string The ID of the list setting
        ---@param modUUID? GUIDSTRING Optional mod UUID, defaults to current mod
        ---@return table<string, boolean> enabledItems - A table where keys are enabled item names and values are true
        GetEnabled = function(listSettingId, modUUID)
            if not modUUID then modUUID = originalModUUID end
            local setting = MCMInstance.Get(listSettingId, modUUID)
            local enabledItems = {}
            if setting and setting.enabled and setting.elements then
                for _, element in ipairs(setting.elements) do
                    if element.enabled then
                        enabledItems[element.name] = true
                    end
                end
            end
            return enabledItems
        end,

        --- Get the raw list setting data
        ---@param listSettingId string The ID of the list setting
        ---@param modUUID? GUIDSTRING Optional mod UUID, defaults to current mod
        ---@return table|nil The raw list setting data or nil if not found
        GetRaw = function(listSettingId, modUUID)
            if not modUUID then modUUID = originalModUUID end
            return MCMInstance.Get(listSettingId, modUUID)
        end,

        --- Check if a specific item is enabled in a list setting
        ---@param listSettingId string The ID of the list setting
        ---@param itemName string The name of the item to check
        ---@param modUUID? GUIDSTRING Optional mod UUID, defaults to current mod
        ---@return boolean enabled - True if the item is enabled, false otherwise
        IsEnabled = function(listSettingId, itemName, modUUID)
            if not modUUID then modUUID = originalModUUID end
            local setting = MCMInstance.Get(listSettingId, modUUID)
            if setting and setting.enabled and setting.elements then
                for _, element in ipairs(setting.elements) do
                    if element.name == itemName then
                        return element.enabled == true
                    end
                end
            end
            return false
        end,

        --- Set the enabled state of an item in a list setting
        ---@param listSettingId string The ID of the list setting
        ---@param itemName string The name of the item to update
        ---@param enabled boolean Whether the item should be enabled
        ---@param modUUID? GUIDSTRING Optional mod UUID, defaults to current mod
        ---@param shouldEmitEvent? boolean Whether to emit a setting changed event (default: true)
        ---@return boolean success True if the update was successful
        SetEnabled = function(listSettingId, itemName, enabled, modUUID, shouldEmitEvent)
            if not modUUID then modUUID = originalModUUID end
            local setting = MCMInstance.Get(listSettingId, modUUID)
            if not setting then return false end

            -- Ensure the elements table exists
            setting.elements = setting.elements or {}

            -- Find and update the element if it exists
            local elementFound = false
            for _, element in ipairs(setting.elements) do
                if element.name == itemName then
                    element.enabled = enabled
                    elementFound = true
                    break
                end
            end

            -- If element doesn't exist, add it
            if not elementFound then
                table.insert(setting.elements, {
                    name = itemName,
                    enabled = enabled
                })
            end

            -- Update the setting
            return MCMInstance.Set(listSettingId, setting, modUUID, shouldEmitEvent)
        end
    }

    -- For backward compatibility
    MCMInstance.GetList = function(...)
        MCMDeprecation(1,
            "MCM.GetList is deprecated and will be removed in a future version. Use MCM.List.GetEnabled instead.")
        return MCMInstance.List.GetEnabled(...)
    end

    MCMInstance.SetListElement = function(...)
        MCMDeprecation(1,
            "MCM.SetListElement is deprecated and will be removed in a future version. Use MCM.List.SetEnabled instead.")
        return MCMInstance.List.SetEnabled(...)
    end

    return MCMInstance
end

-- Setup client-side MCM: only proceed if not on server.
local function injectClientMCMTable(originalModUUID)
    if Ext.IsServer() then return end

    local modTable, _ = getModTableForUUID(originalModUUID)
    if not modTable then return end

    modTable.MCM['SetKeybindingCallback'] = function(settingId, callback, modUUID)
        if not modUUID then modUUID = originalModUUID end

        InputCallbackManager.SetKeybindingCallback(modUUID, settingId, callback)
    end

    -- Function to register callbacks for event_button widgets
    modTable.MCM['SetEventButtonCallback'] = function(settingId, callback, modUUID)
        MCMWarn(0, "SetEventButtonCallback has not been implemented yet.")
        return false
        -- if not modUUID then modUUID = originalModUUID end

        -- -- Use MCMAPI to register the callback
        -- local success = MCMAPI:RegisterEventButtonCallback(modUUID, settingId, callback)

        -- if not success then
        --     MCMWarn(0,
        --         string.format("Failed to register event button callback for setting '%s' in mod '%s'", settingId, modUUID))
        -- else
        --     MCMDebug(1,
        --         string.format("Successfully registered event button callback for setting '%s' in mod '%s'", settingId,
        --             modUUID))
        -- end

        -- return success
    end

    modTable.MCM['OpenMCMWindow'] = function()
        IMGUIAPI:OpenMCMWindow(true)
    end

    modTable.MCM['CloseMCMWindow'] = function()
        IMGUIAPI:CloseMCMWindow(true)
    end

    modTable.MCM['OpenModPage'] = function(tabName, modUUID, shouldEmitEvent)
        if not modUUID then modUUID = originalModUUID end
        IMGUIAPI:OpenModPage(tabName, modUUID, shouldEmitEvent)
    end

    modTable.MCM['InsertModMenuTab'] = function(tabName, tabCallback, modUUID)
        if not modUUID then modUUID = originalModUUID end
        IMGUIAPI:InsertModMenuTab(modUUID, tabName, tabCallback)
    end
end

-- Main function to inject MCM into the mod table
local function injectMCMToModTable(originalModUUID)
    if originalModUUID == ModuleUUID then return end

    MCMPrint(2,
        "Injecting MCM to mod table for modUUID: " ..
        originalModUUID .. " (" .. Ext.Mod.GetMod(originalModUUID).Info.Name .. ")")

    local modTable, modTableName = getModTableForUUID(originalModUUID)
    if not modTable then return end

    MCMPrint(2, "Mod table name: " .. modTableName)
    local MCMInstance = injectSharedMCMTable(modTable, originalModUUID)
    injectClientMCMTable(originalModUUID)

    modTable.MCM = MCMInstance
    MCMSuccess(1, "Successfully injected MCM to mod table for modUUID: " .. originalModUUID)
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
                injectMCMToModTable(value.ModuleUUID)
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

-- Initialize the reverse lookup table with existing Config.json files
initializeReverseLookupTable(ModUUIDToModTableName)

-- Set up the metatable to handle future additions to Mods and possible MCM injection
setupModsMetatable()
