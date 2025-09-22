-- Contains the API methods that will be injected into the MCM table

local warnedDeprecation = {}

-- Table to track which methods are client-only
local CLIENT_ONLY_METHODS = {
    -- Client-only methods
    ['Keybinding.SetCallback'] = true,
    ['EventButton.IsEnabled'] = true,
    ['EventButton.ShowFeedback'] = true,
    ['EventButton.RegisterCallback'] = true,
    ['EventButton.UnregisterCallback'] = true,
    ['EventButton.SetDisabled'] = true,
    ['OpenMCMWindow'] = true,
    ['CloseMCMWindow'] = true,
    ['OpenModPage'] = true,
    ['InsertModMenuTab'] = true,
    ['SetKeybindingCallback'] = true
}

--- Helper function to handle client-only method calls on the server
---@param methodPath string The full path of the method (e.g., 'EventButton.SetDisabled')
---@return function - A function that throws an error if called on the server
local function createClientOnlyStub(methodPath)
    return function(...)
        if Ext.IsServer() then
            error(string.format(
                "MCM API Error: Method '%s' is client-side only and cannot be called from the server context. " ..
                "Please ensure this method is only called from client-side code.", methodPath), 2)
        end
        return nil
    end
end

local function injectClientOnlyStubs(modTable, originalModUUID)
    if Ext.IsServer() then
        for methodPath, _ in pairs(CLIENT_ONLY_METHODS) do
            local parts = {}
            for part in string.gmatch(methodPath, "([^.]+)") do
                table.insert(parts, part)
            end

            local target = modTable.MCM
            for i = 1, #parts - 1 do
                target[parts[i]] = target[parts[i]] or {}
                target = target[parts[i]]
            end

            target[parts[#parts]] = createClientOnlyStub(methodPath)
        end
    end
end

--- Helper function to show a deprecation warning once per mod and method
---@param modUUID string - The UUID of the mod showing the warning
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

-- Create all API methods that will be injected into each mod's MCM table
---@param originalModUUID string The UUID of the mod that will receive these methods
---@param modTable? table Optional mod table to inject methods into directly
---@return table MCMInstance The table containing all API methods
local function createMCMAPIMethods(originalModUUID, modTable)
    local MCMInstance = modTable and modTable.MCM or {}

    -- Initialize sub-tables if they don't exist
    MCMInstance.Keybinding = MCMInstance.Keybinding or {}
    MCMInstance.EventButton = MCMInstance.EventButton or {}
    MCMInstance.List = MCMInstance.List or {}

    -- Core API functions

    --- Get the value of a setting
    ---@param settingId string The ID of the setting to retrieve
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return any The value of the setting, or nil if not found
    MCMInstance.Get = function(settingId, modUUID)
        if not modUUID then modUUID = originalModUUID end
        return MCMAPI:GetSettingValue(settingId, modUUID)
    end

    --- Set the value of a setting
    ---@param settingId string The ID of the setting to set
    ---@param value any The value to set
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@param shouldEmitEvent? boolean Whether to emit a setting changed event
    ---@return boolean success True if the setting was successfully updated
    MCMInstance.Set = function(settingId, value, modUUID, shouldEmitEvent)
        if not modUUID then modUUID = originalModUUID end
        return MCMAPI:SetSettingValue(settingId, value, modUUID, shouldEmitEvent)
    end

    -- Keybindings API
    MCMInstance.Keybinding = {
        --- Get a human-readable string representation of a keybinding
        ---@param settingId string The ID of the keybinding setting
        ---@param modUUID? string Optional mod UUID, defaults to current mod
        ---@return string The formatted keybinding string (e.g., "[Ctrl] + [C]")
        Get = function(settingId, modUUID)
            if not modUUID then modUUID = originalModUUID end
            return KeyPresentationMapping:GetViewKeyForSetting(settingId, modUUID)
        end,

        --- Get the raw keybinding data
        ---@param settingId string The ID of the keybinding setting
        ---@param modUUID? string Optional mod UUID, defaults to current mod
        ---@return table|nil The raw keybinding data structure or nil if not found
        GetRaw = function(settingId, modUUID)
            if not modUUID then modUUID = originalModUUID end
            return MCMAPI:GetSettingValue(settingId, modUUID)
        end,

        -- Keybinding.SetCallback
        ---@param settingId string The ID of the keybinding setting
        ---@param callback function The callback function to be called when the keybinding is pressed
        ---@param modUUID? string Optional mod UUID, defaults to current mod
        ---@return nil
        SetCallback = function(settingId, callback, modUUID)
            if not modUUID then modUUID = originalModUUID end
            InputCallbackManager.SetKeybindingCallback(modUUID, settingId, callback)
        end
    }

    -- List API
    MCMInstance.List = {
        --- Get a table of enabled items in a list setting
        ---@param listSettingId string The ID of the list setting
        ---@param modUUID? string Optional mod UUID, defaults to current mod
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
        ---@param modUUID? string Optional mod UUID, defaults to current mod
        ---@return table|nil The raw list setting data or nil if not found
        GetRaw = function(listSettingId, modUUID)
            if not modUUID then modUUID = originalModUUID end
            return MCMInstance.Get(listSettingId, modUUID)
        end,

        --- Check if a specific item is enabled in a list setting
        ---@param listSettingId string The ID of the list setting
        ---@param itemName string The name of the item to check
        ---@param modUUID? string Optional mod UUID, defaults to current mod
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
        ---@param modUUID? string Optional mod UUID, defaults to current mod
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
        end,

        --- Insert search suggestions for a list_v2 setting
        ---@param listSettingId string The ID of the list setting
        ---@param suggestions string[] Table of suggestion strings to display below the input field
        ---@param modUUID? string Optional mod UUID, defaults to current mod
        ---@return boolean success True if the operation was executed on client, false on server
        InsertSuggestions = function(listSettingId, suggestions, modUUID)
            if not modUUID then modUUID = originalModUUID end
            if type(suggestions) ~= "table" then
                MCMWarn(0, "Invalid 'suggestions' for MCM.List.InsertSuggestions; expected table of strings")
                return false
            end
            IMGUIAPI:InsertListV2Suggestions(listSettingId, suggestions, modUUID)
            return true
        end
    }

    -- Event Button API
    MCMInstance.EventButton = {
        --- Check if an event button is enabled (client only)
        ---@param buttonId string The ID of the event button
        ---@param modUUID? string Optional mod UUID, defaults to current mod
        ---@return boolean|nil isEnabled True if enabled, false if disabled, nil if button not found
        IsEnabled = function(buttonId, modUUID)
            if not modUUID then modUUID = originalModUUID end
            local isDisabled = MCMAPI:IsEventButtonDisabled(tostring(modUUID), buttonId)
            if isDisabled == nil then
                MCMDebug(1, string.format("Button '%s' not found in mod '%s'", buttonId, tostring(modUUID)))
            end
            return not isDisabled
        end,

        --- Show feedback message for an event button (client only)
        ---@param buttonId string The ID of the event button
        ---@param message string The feedback message to display
        ---@param feedbackType string The type of feedback ("success", "error", "info", "warning")
        ---@param modUUID? string The UUID of the mod that owns the button (defaults to current mod)
        ---@param durationInMs? number How long to display the feedback in milliseconds. Defaults to 5000ms.
        ---@return boolean success True if the feedback was shown successfully
        ShowFeedback = function(buttonId, message, feedbackType, modUUID, durationInMs)
            modUUID = modUUID or originalModUUID
            return MCMAPI:ShowEventButtonFeedback(tostring(modUUID), buttonId, message, feedbackType, durationInMs)
        end,

        --- Register a callback function for an event button
        ---@param buttonId string The ID of the event button
        ---@param callback function The callback function to execute when the button is clicked
        ---@param modUUID? string Optional mod UUID, defaults to current mod
        ---@return boolean success True if the callback was registered successfully
        RegisterCallback = function(buttonId, callback, modUUID)
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
        end,

        --- Unregister a callback function for an event button
        ---@param buttonId string The ID of the event button
        ---@param modUUID? string Optional mod UUID, defaults to current mod
        ---@return boolean success True if the callback was unregistered successfully
        UnregisterCallback = function(buttonId, modUUID)
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
        end,

        --- Set the disabled state of an event button
        ---@param buttonId string The ID of the event button
        ---@param disabled boolean Whether the button should be disabled
        ---@param tooltipText? string Optional tooltip text to show when disabled
        ---@param modUUID? string Optional mod UUID, defaults to current mod
        ---@return boolean success True if the state was updated successfully
        SetDisabled = function(buttonId, disabled, tooltipText, modUUID)
            if not modUUID then modUUID = originalModUUID end
            if Ext.IsServer() then return false end

            -- Handle case where tooltipText is omitted and modUUID is passed as third parameter
            if tooltipText ~= nil and type(tooltipText) == "string" and #tooltipText == 36 then -- Check if it might be a UUID
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
        end,

        FeedbackTypes = {
            SUCCESS = "success",
            ERROR = "error",
            INFO = "info",
            WARNING = "warning"
        }
    }

    -- Deprecated methods for backward compatibility.
    -- Do not use these methods.
    function MCMInstance.SetKeybindingCallback(settingId, callback, modUUID)
        showDeprecationWarning(originalModUUID, "SetKeybindingCallback",
            "MCM.SetKeybindingCallback is deprecated and will be removed in a future version. Use MCM.Keybinding.SetCallback instead.")
        return MCMInstance.Keybinding.SetCallback(settingId, callback, modUUID)
    end

    function MCMInstance.GetList(...)
        showDeprecationWarning(originalModUUID, "GetList",
            "MCM.GetList is deprecated and will be removed in a future version. Use MCM.List.GetEnabled instead.")
        return MCMInstance.List.GetEnabled(...)
    end

    function MCMInstance.SetListElement(...)
        showDeprecationWarning(originalModUUID, "SetListElement",
            "MCM.SetListElement is deprecated and will be removed in a future version. Use MCM.List.SetEnabled instead.")
        return MCMInstance.List.SetEnabled(...)
    end

    -- Client-only methods (will be stubbed on server)

    --- Open the MCM window
    ---@return nil
    function MCMInstance.OpenMCMWindow()
        IMGUIAPI:OpenMCMWindow(true)
    end

    --- Close the MCM window
    ---@return nil
    function MCMInstance.CloseMCMWindow()
        IMGUIAPI:CloseMCMWindow(true)
    end

    --- Open a mod page in the MCM
    ---@param tabName string The name of the tab to open
    ---@param modUUID? string The UUID of the mod, defaults to current mod
    ---@param shouldEmitEvent? boolean Whether to emit the mod page open event, defaults to true
    ---@return nil
    function MCMInstance.OpenModPage(tabName, modUUID, shouldEmitEvent)
        if not modUUID then modUUID = originalModUUID end
        IMGUIAPI:OpenModPage(tabName, modUUID, shouldEmitEvent)
    end

    --- Insert a new tab for a mod in the MCM
    ---@param tabName string The name of the tab to be inserted
    ---@param tabCallback function The callback function to create the tab
    ---@param modUUID? string The UUID of the mod, defaults to current mod
    ---@return nil
    function MCMInstance.InsertModMenuTab(tabName, tabCallback, modUUID)
        if not modUUID then modUUID = originalModUUID end
        IMGUIAPI:InsertModMenuTab(modUUID, tabName, tabCallback)
    end

    -- Inject client-only method stubs for server context
    injectClientOnlyStubs({ MCM = MCMInstance }, originalModUUID)

    return MCMInstance
end

-- Public API
local MCMAPIMethods = {
    createMCMAPIMethods = createMCMAPIMethods
}

return MCMAPIMethods
