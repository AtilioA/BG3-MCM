-- MCM API Implementations
-- Contains the core implementations of all MCM API methods

local MCMAPIUtils = Ext.Require("Shared/Helpers/MCM/GlobalTable/MCMAPIUtils.lua")

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

---@class MCMGetArgs
---@field settingId string
---@field modUUID? string

---@class MCMSetArgs
---@field settingId string
---@field value any
---@field modUUID? string
---@field shouldEmitEvent? boolean

---@class MCMKeybindingGetArgs
---@field settingId string
---@field modUUID? string

---@class MCMKeybindingSetCallbackArgs
---@field settingId string
---@field callback function
---@field modUUID? string

---@class MCMListGetArgs
---@field listSettingId string
---@field modUUID? string

---@class MCMListIsEnabledArgs
---@field listSettingId string
---@field itemName string
---@field modUUID? string

---@class MCMListSetEnabledArgs
---@field listSettingId string
---@field itemName string
---@field enabled boolean
---@field modUUID? string
---@field shouldEmitEvent? boolean

---@class MCMListInsertSuggestionsArgs
---@field listSettingId string
---@field suggestions string[]
---@field modUUID? string

---@class MCMEventButtonStateArgs
---@field buttonId string
---@field modUUID? string

---@class MCMEventButtonFeedbackArgs
---@field buttonId string
---@field message string
---@field feedbackType string
---@field modUUID? string
---@field durationInMs? number

---@class MCMEventButtonCallbackArgs
---@field buttonId string
---@field callback function
---@field modUUID? string

---@class MCMEventButtonSetDisabledArgs
---@field buttonId string
---@field disabled boolean
---@field tooltipText? string
---@field modUUID? string

---@class MCMOpenModPageArgs
---@field tabName string
---@field modUUID? string
---@field shouldEmitEvent? boolean

---@class MCMInsertModMenuTabArgs
---@field tabName string
---@field tabCallback function
---@field modUUID? string

---@alias MCMEmptyArgs {}

--- Implementation: Get the value of a setting
---@param args MCMGetArgs
---@return any The value of the setting, or nil if not found
local function Get_Impl(args)
    return MCMAPI:GetSettingValue(args.settingId, args.modUUID)
end

--- Implementation: Set the value of a setting
---@param args MCMSetArgs
---@return boolean success True if the setting was successfully updated
local function Set_Impl(args)
    return MCMAPI:SetSettingValue(args.settingId, args.value, args.modUUID, args.shouldEmitEvent)
end

--- Create the core MCM API methods
---@param originalModUUID string The UUID of the mod that will receive these methods
---@return table MCMInstance The table containing all API methods
function MCMAPIImplementations.createCoreMethods(originalModUUID)
    local MCMInstance = {}

    --- Get the value of a setting
    ---@param settingId string|MCMGetArgs The ID of the setting to retrieve, or an argument table
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return any The value of the setting, or nil if not found
    MCMInstance.Get = MCMAPIUtils.WithFlexibleArgs(
        Get_Impl,
        { "settingId", "modUUID" },
        { modUUID = originalModUUID }
    )

    --- Set the value of a setting
    ---@param settingId string|MCMSetArgs The ID of the setting to set, or an argument table
    ---@param value any The value to set
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@param shouldEmitEvent? boolean Whether to emit a setting changed event
    ---@return boolean success True if the setting was successfully updated
    MCMInstance.Set = MCMAPIUtils.WithFlexibleArgs(
        Set_Impl,
        { "settingId", "value", "modUUID", "shouldEmitEvent" },
        { modUUID = originalModUUID }
    )

    return MCMInstance
end

--- Implementation: Get a human-readable string representation of a keybinding
---@param args MCMKeybindingGetArgs
---@return string The formatted keybinding string
local function KeybindingGet_Impl(args)
    return KeyPresentationMapping:GetViewKeyForSetting(args.settingId, args.modUUID)
end

--- Implementation: Get the raw keybinding data
---@param args MCMKeybindingGetArgs
---@return table|nil The raw keybinding data structure or nil if not found
local function KeybindingGetRaw_Impl(args)
    return MCMAPI:GetSettingValue(args.settingId, args.modUUID)
end

--- Implementation: Set a callback for keybinding
---@param args MCMKeybindingSetCallbackArgs
---@return nil
local function KeybindingSetCallback_Impl(args)
    InputCallbackManager.SetKeybindingCallback(args.modUUID, args.settingId, args.callback)
end

--- Create the Keybinding API methods
---@param originalModUUID string The UUID of the mod that will receive these methods
---@return table KeybindingAPI The table containing Keybinding API methods
function MCMAPIImplementations.createKeybindingAPI(originalModUUID)
    local KeybindingAPI = {}

    --- Get a human-readable string representation of a keybinding
    ---@param settingId string|MCMKeybindingGetArgs The ID of the keybinding setting, or an argument table
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return string The formatted keybinding string (e.g., "[Ctrl] + [C]")
    KeybindingAPI.Get = MCMAPIUtils.WithFlexibleArgs(
        KeybindingGet_Impl,
        { "settingId", "modUUID" },
        { modUUID = originalModUUID }
    )

    --- Get the raw keybinding data
    ---@param settingId string|MCMKeybindingGetArgs The ID of the keybinding setting, or an argument table
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return table|nil The raw keybinding data structure or nil if not found
    KeybindingAPI.GetRaw = MCMAPIUtils.WithFlexibleArgs(
        KeybindingGetRaw_Impl,
        { "settingId", "modUUID" },
        { modUUID = originalModUUID }
    )

    --- Set a callback for keybinding
    ---@param settingId string|MCMKeybindingSetCallbackArgs The ID of the keybinding setting, or an argument table
    ---@param callback function The callback function to be called when the keybinding is pressed
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return nil
    KeybindingAPI.SetCallback = MCMAPIUtils.WithFlexibleArgs(
        KeybindingSetCallback_Impl,
        { "settingId", "callback", "modUUID" },
        { modUUID = originalModUUID }
    )

    return KeybindingAPI
end

--- Implementation: Get a table of enabled items in a list setting
---@param args MCMListGetArgs
---@return table<string, boolean> enabledItems
local function ListGetEnabled_Impl(args)
    local setting = MCMAPI:GetSettingValue(args.listSettingId, args.modUUID)
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

--- Implementation: Get the raw list setting data
---@param args MCMListGetArgs
---@return table|nil The raw list setting data or nil if not found
local function ListGetRaw_Impl(args)
    return MCMAPI:GetSettingValue(args.listSettingId, args.modUUID)
end

--- Implementation: Check if a specific item is enabled in a list setting
---@param args MCMListIsEnabledArgs
---@return boolean enabled
local function ListIsEnabled_Impl(args)
    local setting = MCMAPI:GetSettingValue(args.listSettingId, args.modUUID)
    if setting and setting.enabled and setting.elements then
        for _, element in ipairs(setting.elements) do
            if element.name == args.itemName then
                return element.enabled == true
            end
        end
    end
    return false
end

--- Implementation: Set the enabled state of an item in a list setting
---@param args MCMListSetEnabledArgs
---@return boolean success
local function ListSetEnabled_Impl(args)
    local setting = MCMAPI:GetSettingValue(args.listSettingId, args.modUUID)
    if not setting then return false end

    -- Ensure the elements table exists
    setting.elements = setting.elements or {}

    -- Find and update the element if it exists
    local elementFound = false
    for _, element in ipairs(setting.elements) do
        if element.name == args.itemName then
            element.enabled = args.enabled
            elementFound = true
            break
        end
    end

    -- If element doesn't exist, add it
    if not elementFound then
        table.insert(setting.elements, {
            name = args.itemName,
            enabled = args.enabled
        })
    end

    -- Update the setting
    return MCMAPI:SetSettingValue(args.listSettingId, setting, args.modUUID, args.shouldEmitEvent)
end

--- Implementation: Insert search suggestions for a list_v2 setting
---@param args MCMListInsertSuggestionsArgs
---@return boolean success
local function ListInsertSuggestions_Impl(args)
    if type(args.suggestions) ~= "table" then
        MCMWarn(0, "Invalid 'suggestions' for MCM.List.InsertSuggestions; expected table of strings")
        return false
    end
    IMGUIAPI:InsertListV2Suggestions(args.listSettingId, args.suggestions, args.modUUID)
    return true
end

--- Create the List API methods
---@param originalModUUID string The UUID of the mod that will receive these methods
---@return table ListAPI The table containing List API methods
function MCMAPIImplementations.createListAPI(originalModUUID)
    local ListAPI = {}

    --- Get a table of enabled items in a list setting
    ---@param listSettingId string|MCMListGetArgs The ID of the list setting, or an argument table
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return table<string, boolean> enabledItems - A table where keys are enabled item names and values are true
    ListAPI.GetEnabled = MCMAPIUtils.WithFlexibleArgs(
        ListGetEnabled_Impl,
        { "listSettingId", "modUUID" },
        { modUUID = originalModUUID }
    )

    --- Get the raw list setting data
    ---@param listSettingId string|MCMListGetArgs The ID of the list setting, or an argument table
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return table|nil The raw list setting data or nil if not found
    ListAPI.GetRaw = MCMAPIUtils.WithFlexibleArgs(
        ListGetRaw_Impl,
        { "listSettingId", "modUUID" },
        { modUUID = originalModUUID }
    )

    --- Check if a specific item is enabled in a list setting
    ---@param listSettingId string|MCMListIsEnabledArgs The ID of the list setting, or an argument table
    ---@param itemName string The name of the item to check
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return boolean enabled - True if the item is enabled, false otherwise
    ListAPI.IsEnabled = MCMAPIUtils.WithFlexibleArgs(
        ListIsEnabled_Impl,
        { "listSettingId", "itemName", "modUUID" },
        { modUUID = originalModUUID }
    )

    --- Set the enabled state of an item in a list setting
    ---@param listSettingId string|MCMListSetEnabledArgs The ID of the list setting, or an argument table
    ---@param itemName string The name of the item to update
    ---@param enabled boolean Whether the item should be enabled
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@param shouldEmitEvent? boolean Whether to emit a setting changed event (default: true)
    ---@return boolean success True if the update was successful
    ListAPI.SetEnabled = MCMAPIUtils.WithFlexibleArgs(
        ListSetEnabled_Impl,
        { "listSettingId", "itemName", "enabled", "modUUID", "shouldEmitEvent" },
        { modUUID = originalModUUID }
    )

    --- Insert search suggestions for a list_v2 setting
    ---@param listSettingId string|MCMListInsertSuggestionsArgs The ID of the list setting, or an argument table
    ---@param suggestions string[] Table of suggestion strings to display below the input field
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return boolean success True if the operation was executed on client, false on server
    ListAPI.InsertSuggestions = MCMAPIUtils.WithFlexibleArgs(
        ListInsertSuggestions_Impl,
        { "listSettingId", "suggestions", "modUUID" },
        { modUUID = originalModUUID }
    )

    return ListAPI
end

--- Implementation: Check if an event button is enabled
---@param args MCMEventButtonStateArgs
---@return boolean|nil isEnabled
local function EventButtonIsEnabled_Impl(args)
    local isDisabled = MCMAPI:IsEventButtonDisabled(tostring(args.modUUID), args.buttonId)
    if isDisabled == nil then
        MCMDebug(1, string.format("Button '%s' not found in mod '%s'", args.buttonId, tostring(args.modUUID)))
    end
    return not isDisabled
end

--- Implementation: Show feedback message for an event button
---@param args MCMEventButtonFeedbackArgs
---@return boolean success
local function EventButtonShowFeedback_Impl(args)
    return MCMAPI:ShowEventButtonFeedback(tostring(args.modUUID), args.buttonId, args.message, args.feedbackType,
        args.durationInMs)
end

--- Implementation: Register a callback function for an event button
---@param args MCMEventButtonCallbackArgs
---@return boolean success
local function EventButtonRegisterCallback_Impl(args)
    if Ext.IsServer() then return false end
    local success = MCMAPI:RegisterEventButtonCallback(args.modUUID, args.buttonId, args.callback)
    if not success then
        MCMWarn(0,
            string.format("Failed to register event button callback for button '%s' in mod '%s'", args.buttonId,
                args.modUUID))
    else
        MCMDebug(1,
            string.format("Successfully registered event button callback for button '%s' in mod '%s'", args.buttonId,
                args.modUUID))
    end
    return success
end

--- Implementation: Unregister a callback function for an event button
---@param args MCMEventButtonStateArgs
---@return boolean success
local function EventButtonUnregisterCallback_Impl(args)
    if Ext.IsServer() then return false end
    local success = MCMAPI:UnregisterEventButtonCallback(args.modUUID, args.buttonId)
    if not success then
        MCMWarn(0,
            string.format("Failed to unregister event button callback for button '%s' in mod '%s'", args.buttonId,
                args.modUUID))
    else
        MCMDebug(1,
            string.format("Successfully unregistered event button callback for button '%s' in mod '%s'", args.buttonId,
                args.modUUID))
    end
    return success
end

--- Implementation: Set the disabled state of an event button
---@param args MCMEventButtonSetDisabledArgs
---@return boolean success
local function EventButtonSetDisabled_Impl(args)
    if Ext.IsServer() then return false end


    local success = MCMAPI:SetEventButtonDisabled(args.modUUID, args.buttonId, args.disabled, args.tooltipText)
    if not success then
        MCMWarn(0,
            string.format("Failed to set disabled state for button '%s' in mod '%s'", args.buttonId, args.modUUID))
    else
        MCMDebug(1,
            string.format("Successfully set disabled state for button '%s' in mod '%s' to %s",
                args.buttonId, args.modUUID, tostring(args.disabled)))
    end
    return success
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
    ---@param buttonId string|MCMEventButtonStateArgs The ID of the event button, or an argument table
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return boolean|nil isEnabled True if enabled, false if disabled, nil if button not found
    EventButtonAPI.IsEnabled = MCMAPIUtils.WithFlexibleArgs(
        EventButtonIsEnabled_Impl,
        { "buttonId", "modUUID" },
        { modUUID = originalModUUID }
    )

    --- Show feedback message for an event button (client only)
    ---@param buttonId string|MCMEventButtonFeedbackArgs The ID of the event button, or an argument table
    ---@param message string The feedback message to display
    ---@param feedbackType string The type of feedback ("success", "error", "info", "warning")
    ---@param modUUID? string The UUID of the mod that owns the button (defaults to current mod)
    ---@param durationInMs? number How long to display the feedback in milliseconds. Defaults to 5000ms.
    ---@return boolean success True if the feedback was shown successfully
    EventButtonAPI.ShowFeedback = MCMAPIUtils.WithFlexibleArgs(
        EventButtonShowFeedback_Impl,
        { "buttonId", "message", "feedbackType", "modUUID", "durationInMs" },
        { modUUID = originalModUUID }
    )

    --- Register a callback function for an event button
    ---@param buttonId string|MCMEventButtonCallbackArgs The ID of the event button, or an argument table
    ---@param callback function The callback function to execute when the button is clicked
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return boolean success True if the callback was registered successfully
    EventButtonAPI.RegisterCallback = MCMAPIUtils.WithFlexibleArgs(
        EventButtonRegisterCallback_Impl,
        { "buttonId", "callback", "modUUID" },
        { modUUID = originalModUUID }
    )

    --- Unregister a callback function for an event button
    ---@param buttonId string|MCMEventButtonStateArgs The ID of the event button, or an argument table
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return boolean success True if the callback was unregistered successfully
    EventButtonAPI.UnregisterCallback = MCMAPIUtils.WithFlexibleArgs(
        EventButtonUnregisterCallback_Impl,
        { "buttonId", "modUUID" },
        { modUUID = originalModUUID }
    )

    --- Set the disabled state of an event button
    ---@param buttonId string|MCMEventButtonSetDisabledArgs The ID of the event button, or an argument table
    ---@param disabled boolean Whether the button should be disabled
    ---@param tooltipText? string Optional tooltip text to show when disabled
    ---@param modUUID? string Optional mod UUID, defaults to current mod
    ---@return boolean success True if the state was updated successfully
    EventButtonAPI.SetDisabled = MCMAPIUtils.WithFlexibleArgs(
        EventButtonSetDisabled_Impl,
        { "buttonId", "disabled", "tooltipText", "modUUID" },
        { modUUID = originalModUUID }
    )

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

--- Implementation: Open the MCM window
---@param args MCMEmptyArgs
---@return nil
local function OpenMCMWindow_Impl(args)
    IMGUIAPI:OpenMCMWindow(true)
end

--- Implementation: Close the MCM window
---@param args MCMEmptyArgs
---@return nil
local function CloseMCMWindow_Impl(args)
    IMGUIAPI:CloseMCMWindow(true)
end

--- Implementation: Open a mod page in the MCM
---@param args MCMOpenModPageArgs
---@return nil
local function OpenModPage_Impl(args)
    IMGUIAPI:OpenModPage(args.tabName, args.modUUID, args.shouldEmitEvent)
end

--- Implementation: Insert a new tab for a mod in the MCM
---@param args MCMInsertModMenuTabArgs
---@return nil
local function InsertModMenuTab_Impl(args)
    IMGUIAPI:InsertModMenuTab(args.modUUID, args.tabName, args.tabCallback)
end

--- Create client-only methods
---@param MCMInstance table The MCM instance to add client-only methods to
---@param originalModUUID string The UUID of the mod that will receive these methods
function MCMAPIImplementations.addClientOnlyMethods(MCMInstance, originalModUUID)
    --- Open the MCM window
    ---@return nil
    MCMInstance.OpenMCMWindow = MCMAPIUtils.WithFlexibleArgs(
        OpenMCMWindow_Impl,
        {},
        {}
    )

    --- Close the MCM window
    ---@return nil
    MCMInstance.CloseMCMWindow = MCMAPIUtils.WithFlexibleArgs(
        CloseMCMWindow_Impl,
        {},
        {}
    )

    --- Open a mod page in the MCM
    ---@param tabName string|MCMOpenModPageArgs The name of the tab to open, or an argument table
    ---@param modUUID? string The UUID of the mod, defaults to current mod
    ---@param shouldEmitEvent? boolean Whether to emit the mod page open event, defaults to true
    ---@return nil
    MCMInstance.OpenModPage = MCMAPIUtils.WithFlexibleArgs(
        OpenModPage_Impl,
        { "tabName", "modUUID", "shouldEmitEvent" },
        { modUUID = originalModUUID }
    )

    --- Insert a new tab for a mod in the MCM
    ---@param tabName string|MCMInsertModMenuTabArgs The name of the tab to be inserted, or an argument table
    ---@param tabCallback function The callback function to create the tab
    ---@param modUUID? string The UUID of the mod, defaults to current mod
    ---@return nil
    MCMInstance.InsertModMenuTab = MCMAPIUtils.WithFlexibleArgs(
        InsertModMenuTab_Impl,
        { "tabName", "tabCallback", "modUUID" },
        { modUUID = originalModUUID }
    )
end

return MCMAPIImplementations
