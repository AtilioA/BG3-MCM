-- Contains the API methods that will be injected into the MCM table

local warnedDeprecation = {}

--- Helper function to show a deprecation warning once per mod and method
---@param modUUID GUIDSTRING The UUID of the mod showing the warning
---@param methodName string The name of the deprecated method
---@param message string The deprecation message
local function showDeprecationWarning(modUUID, methodName, message)
    if not warnedDeprecation[modUUID] then
        warnedDeprecation[modUUID] = {}
    end
    if not warnedDeprecation[modUUID][methodName] then
        MCMDeprecation(1, Ext.Mod.GetMod(modUUID).Info.Name .. ": " .. message)
        warnedDeprecation[modUUID][methodName] = true
    end
end

-- Create the API methods that will be injected into each mod's MCM table
---@param originalModUUID GUIDSTRING The UUID of the mod that will receive these methods
---@return table MCMInstance The table containing all API methods
local function createMCMAPIMethods(originalModUUID)
    local MCMInstance = {}

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

    -- EventButton API
    MCMInstance.EventButton = {
        --- Check if an event button is disabled
        ---@param buttonId string The ID of the event button
        ---@param modUUID? GUIDSTRING Optional mod UUID, defaults to current mod
        ---@return boolean|nil isDisabled True if disabled, false if enabled, nil if button not found
        IsDisabled = function(buttonId, modUUID)
            if not modUUID then modUUID = originalModUUID end
            if Ext.IsServer() then return nil end

            local isDisabled = MCMAPI:IsEventButtonDisabled(modUUID, buttonId)
            if isDisabled == nil then
                MCMDebug(1, string.format("Button '%s' not found in mod '%s'", buttonId, modUUID))
            end
            return isDisabled
        end
    }

    -- Keybindings API
    MCMInstance.Keybinding = {
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
        showDeprecationWarning(originalModUUID, "GetList",
            "MCM.GetList is deprecated and will be removed in a future version. Use MCM.List.GetEnabled instead.")
        return MCMInstance.List.GetEnabled(...)
    end

    MCMInstance.SetListElement = function(...)
        showDeprecationWarning(originalModUUID, "SetListElement",
            "MCM.SetListElement is deprecated and will be removed in a future version. Use MCM.List.SetEnabled instead.")
        return MCMInstance.List.SetEnabled(...)
    end

    return MCMInstance
end

-- Create client-side API methods (only available on the client)
---@param originalModUUID GUIDSTRING The UUID of the mod that will receive these methods
---@param modTable table The mod table to inject the methods into
local function createClientAPIMethods(originalModUUID, modTable)
    if Ext.IsServer() then return end

    if not modTable then return end
    if not modTable.MCM then
        modTable.MCM = {}
    end

    if not modTable.MCM.Keybinding then
        modTable.MCM.Keybinding = {}
    end
    modTable.MCM.Keybinding['SetCallback'] = function(settingId, callback, modUUID)
        if not modUUID then modUUID = originalModUUID end

        InputCallbackManager.SetKeybindingCallback(modUUID, settingId, callback)
    end

    if not modTable.MCM.EventButton then
        modTable.MCM.EventButton = {}
    end
    --- Register a callback function for an event button
    ---@param buttonId string The ID of the event button
    ---@param callback function The callback function to execute when the button is clicked
    ---@param modUUID? GUIDSTRING Optional mod UUID, defaults to current mod
    ---@return boolean success True if the callback was registered successfully
    modTable.MCM.EventButton['RegisterCallback'] = function(buttonId, callback, modUUID)
        if not modUUID then modUUID = originalModUUID end
        if Ext.IsServer() then return false end
        local success = MCMAPI:RegisterEventButtonCallback(modUUID, buttonId, callback)
        if not success then
            MCMWarn(0,
                string.format("Failed to register event button callback for button '%s' in mod '%s'", buttonId,
                    modUUID))
        else
            MCMDebug(1,
                string.format("Successfully registered event button callback for button '%s' in mod '%s'", buttonId,
                    modUUID))
        end
        return success
    end

    --- Unregister a callback function for an event button
    ---@param buttonId string The ID of the event button
    ---@param modUUID? GUIDSTRING Optional mod UUID, defaults to current mod
    ---@return boolean success True if the callback was unregistered successfully
    modTable.MCM.EventButton['UnregisterCallback'] = function(buttonId, modUUID)
        if not modUUID then modUUID = originalModUUID end
        if Ext.IsServer() then return false end
        local success = MCMAPI:UnregisterEventButtonCallback(modUUID, buttonId)
        if not success then
            MCMWarn(0,
                string.format("Failed to unregister event button callback for button '%s' in mod '%s'", buttonId,
                    modUUID))
        else
            MCMDebug(1,
                string.format("Successfully unregistered event button callback for button '%s' in mod '%s'", buttonId,
                    modUUID))
        end
        return success
    end

    --- Set the disabled state of an event button
    ---@param buttonId string The ID of the event button
    ---@param disabled boolean Whether the button should be disabled
    ---@param tooltipText? string Optional tooltip text to show when disabled
    ---@param modUUID? GUIDSTRING Optional mod UUID, defaults to current mod
    ---@return boolean success True if the state was updated successfully
    modTable.MCM.EventButton['SetDisabled'] = function(buttonId, disabled, tooltipText, modUUID)
        if not modUUID then modUUID = originalModUUID end
        if Ext.IsServer() then return false end

        -- Handle case where tooltipText is omitted and modUUID is passed as third parameter
        if tooltipText ~= nil and type(tooltipText) == "string" and #tooltipText == 36 then     -- Check if it might be a UUID
            modUUID = tooltipText
            tooltipText = nil
        end

        local success = MCMAPI:SetEventButtonDisabled(modUUID, buttonId, disabled, tooltipText)
        if not success then
            MCMWarn(0,
                string.format("Failed to set disabled state for button '%s' in mod '%s'", buttonId, modUUID))
        else
            MCMDebug(1,
                string.format("Successfully set disabled state for button '%s' in mod '%s' to %s",
                    buttonId, modUUID, tostring(disabled)))
        end
        return success
    end

    modTable.MCM['SetKeybindingCallback'] = function(settingId, callback, modUUID)
        if not modUUID then modUUID = originalModUUID end
        showDeprecationWarning(originalModUUID, "SetKeybindingCallback",
            "MCM.SetKeybindingCallback is deprecated and will be removed in a future version. Use MCM.Keybinding.SetCallback instead.")
        return modTable.MCM.Keybinding.SetCallback(settingId, callback, modUUID)
    end

    -- -- Function to register callbacks for event_button widgets
    -- if not modTable.MCM.EventButton then
    --     modTable.MCM.EventButton = {}
    -- end
    -- modTable.MCM.EventButton['SetCallback'] = function(settingId, callback, modUUID)
    --     if not modUUID then modUUID = originalModUUID end

    --     local success = MCMAPI:RegisterEventButtonCallback(modUUID, settingId, callback)

    --     if not success then
    --         MCMWarn(0,
    --             string.format("Failed to register event button callback for setting '%s' in mod '%s'", settingId, modUUID))
    --     else
    --         MCMDebug(1,
    --             string.format("Successfully registered event button callback for setting '%s' in mod '%s'", settingId,
    --                 modUUID))
    --     end

    --     return success
    -- end

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

-- Public API
local MCMAPIMethods = {
    createMCMAPIMethods = createMCMAPIMethods,
    createClientAPIMethods = createClientAPIMethods
}

return MCMAPIMethods
