-- MCM API Implementations
-- Contains the core implementations of all MCM API methods

local MCMAPIUtils = require("Mods/BG3MCM/ScriptExtender/Lua/Shared/Helpers/MCM/GlobalTable/MCMAPIUtils")

local MCMAPIImplementations = {}

-- Table to track which methods are client-only (used by the factory)
MCMAPIImplementations.CLIENT_ONLY_METHODS = {
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

--- Create the core MCM API methods
---@param originalModUUID string The UUID of the mod that will receive these methods
---@return table MCMInstance The table containing all API methods
function MCMAPIImplementations.createCoreMethods(originalModUUID)
    local MCMInstance = {}

    --- Get the value of a setting
    ---@param settingId string The ID of the setting to retrieve
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return any The value of the setting, or nil if not found
    function MCMInstance.Get(settingId, modUUID)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
        return MCMAPI:GetSettingValue(settingId, modUUID)
    end

    --- Set the value of a setting
    ---@param settingId string The ID of the setting to set
    ---@param value any The value to set
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@param shouldEmitEvent? boolean Whether to emit a setting changed event
    ---@return boolean success True if the setting was successfully updated
    function MCMInstance.Set(settingId, value, modUUID, shouldEmitEvent)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
        return MCMAPI:SetSettingValue(settingId, value, modUUID, shouldEmitEvent)
    end

    return MCMInstance
end

--- Create the Keybinding API methods
---@param originalModUUID string The UUID of the mod that will receive these methods
---@return table KeybindingAPI The table containing Keybinding API methods
function MCMAPIImplementations.createKeybindingAPI(originalModUUID)
    local KeybindingAPI = {}

    --- Get a human-readable string representation of a keybinding
    ---@param settingId string The ID of the keybinding setting
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return string The formatted keybinding string (e.g., "[Ctrl] + [C]")
    function KeybindingAPI.Get(settingId, modUUID)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
        return KeyPresentationMapping:GetViewKeyForSetting(settingId, modUUID)
    end

    --- Get the raw keybinding data
    ---@param settingId string The ID of the keybinding setting
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return table|nil The raw keybinding data structure or nil if not found
    function KeybindingAPI.GetRaw(settingId, modUUID)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
        return MCMAPI:GetSettingValue(settingId, modUUID)
    end

    --- Set a callback for keybinding
    ---@param settingId string The ID of the keybinding setting
    ---@param callback function The callback function to be called when the keybinding is pressed
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return nil
    function KeybindingAPI.SetCallback(settingId, callback, modUUID)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
        InputCallbackManager.SetKeybindingCallback(modUUID, settingId, callback)
    end

    return KeybindingAPI
end

--- Create the List API methods
---@param originalModUUID string The UUID of the mod that will receive these methods
---@return table ListAPI The table containing List API methods
function MCMAPIImplementations.createListAPI(originalModUUID)
    local ListAPI = {}

    --- Get a table of enabled items in a list setting
    ---@param listSettingId string The ID of the list setting
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return table<string, boolean> enabledItems - A table where keys are enabled item names and values are true
    function ListAPI.GetEnabled(listSettingId, modUUID)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
        local setting = MCMAPI:GetSettingValue(listSettingId, modUUID)
        local enabledItems = {}
        if setting and setting.enabled and setting.elements then
            for _, element in ipairs(setting.elements) do
                if element.enabled then
                    enabledItems[element.name] = true
                end
            end
        end
        return enabledItems
    end

    --- Get the raw list setting data
    ---@param listSettingId string The ID of the list setting
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return table|nil The raw list setting data or nil if not found
    function ListAPI.GetRaw(listSettingId, modUUID)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
        return MCMAPI:GetSettingValue(listSettingId, modUUID)
    end

    --- Check if a specific item is enabled in a list setting
    ---@param listSettingId string The ID of the list setting
    ---@param itemName string The name of the item to check
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return boolean enabled - True if the item is enabled, false otherwise
    function ListAPI.IsEnabled(listSettingId, itemName, modUUID)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
        local setting = MCMAPI:GetSettingValue(listSettingId, modUUID)
        if setting and setting.enabled and setting.elements then
            for _, element in ipairs(setting.elements) do
                if element.name == itemName then
                    return element.enabled == true
                end
            end
        end
        return false
    end

    --- Set the enabled state of an item in a list setting
    ---@param listSettingId string The ID of the list setting
    ---@param itemName string The name of the item to update
    ---@param enabled boolean Whether the item should be enabled
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@param shouldEmitEvent? boolean Whether to emit a setting changed event (default: true)
    ---@return boolean success True if the update was successful
    function ListAPI.SetEnabled(listSettingId, itemName, enabled, modUUID, shouldEmitEvent)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
        local setting = MCMAPI:GetSettingValue(listSettingId, modUUID)
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
        return MCMAPI:SetSettingValue(listSettingId, setting, modUUID, shouldEmitEvent)
    end

    --- Insert search suggestions for a list_v2 setting
    ---@param listSettingId string The ID of the list setting
    ---@param suggestions string[] Table of suggestion strings to display below the input field
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return boolean success True if the operation was executed on client, false on server
    function ListAPI.InsertSuggestions(listSettingId, suggestions, modUUID)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
        if type(suggestions) ~= "table" then
            MCMWarn(0, "Invalid 'suggestions' for MCM.List.InsertSuggestions; expected table of strings")
            return false
        end
        IMGUIAPI:InsertListV2Suggestions(listSettingId, suggestions, modUUID)
        return true
    end

    return ListAPI
end

--- Create the Event Button API methods
---@param originalModUUID string The UUID of the mod that will receive these methods
---@return table EventButtonAPI The table containing Event Button API methods
function MCMAPIImplementations.createEventButtonAPI(originalModUUID)
    local EventButtonAPI = {
        FeedbackTypes = {
            SUCCESS = "success",
            ERROR = "error",
            INFO = "info",
            WARNING = "warning"
        }
    }

    --- Check if an event button is enabled (client only)
    ---@param buttonId string The ID of the event button
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return boolean|nil isEnabled True if enabled, false if disabled, nil if button not found
    function EventButtonAPI.IsEnabled(buttonId, modUUID)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
        local isDisabled = MCMAPI:IsEventButtonDisabled(tostring(modUUID), buttonId)
        if isDisabled == nil then
            MCMDebug(1, string.format("Button '%s' not found in mod '%s'", buttonId, tostring(modUUID)))
        end
        return not isDisabled
    end

    --- Show feedback message for an event button (client only)
    ---@param buttonId string The ID of the event button
    ---@param message string The feedback message to display
    ---@param feedbackType string The type of feedback ("success", "error", "info", "warning")
    ---@param modUUID? string The UUID of the mod that owns the button (defaults to current mod)
    ---@param durationInMs? number How long to display the feedback in milliseconds. Defaults to 5000ms.
    ---@return boolean success True if the feedback was shown successfully
    function EventButtonAPI.ShowFeedback(buttonId, message, feedbackType, modUUID, durationInMs)
        modUUID = modUUID or originalModUUID
        return MCMAPI:ShowEventButtonFeedback(tostring(modUUID), buttonId, message, feedbackType, durationInMs)
    end

    --- Register a callback function for an event button
    ---@param buttonId string The ID of the event button
    ---@param callback function The callback function to execute when the button is clicked
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return boolean success True if the callback was registered successfully
    function EventButtonAPI.RegisterCallback(buttonId, callback, modUUID)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
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
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return boolean success True if the callback was unregistered successfully
    function EventButtonAPI.UnregisterCallback(buttonId, modUUID)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
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
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return boolean success True if the state was updated successfully
    function EventButtonAPI.SetDisabled(buttonId, disabled, tooltipText, modUUID)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
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
    end

    return EventButtonAPI
end

function MCMAPIImplementations.addDeprecatedMethods(MCMInstance, modUUID)
    local function deprecated(oldName, newPath, impl)
        MCMInstance[oldName] = function(...)
            MCMAPIUtils.WarnOnce(modUUID, oldName,
                string.format("MCM.%s is deprecated. Use MCM.%s instead.", oldName, newPath))
            return impl(...)
        end
    end

    deprecated("SetKeybindingCallback", "Keybinding.SetCallback", MCMInstance.Keybinding.SetCallback)
    deprecated("GetList", "List.GetEnabled", MCMInstance.List.GetEnabled)
    deprecated("SetListElement", "List.SetEnabled", MCMInstance.List.SetEnabled)
end

--- Create client-only methods
---@param MCMInstance table The MCM instance to add client-only methods to
---@param originalModUUID string The UUID of the mod that will receive these methods
function MCMAPIImplementations.addClientOnlyMethods(MCMInstance, originalModUUID)
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
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
        IMGUIAPI:OpenModPage(tabName, modUUID, shouldEmitEvent)
    end

    --- Insert a new tab for a mod in the MCM
    ---@param tabName string The name of the tab to be inserted
    ---@param tabCallback function The callback function to create the tab
    ---@param modUUID? string The UUID of the mod, defaults to current mod
    ---@return nil
    function MCMInstance.InsertModMenuTab(tabName, tabCallback, modUUID)
        modUUID = MCMAPIUtils.EnsureModUUID(modUUID, originalModUUID)
        IMGUIAPI:InsertModMenuTab(modUUID, tabName, tabCallback)
    end
end

return MCMAPIImplementations
