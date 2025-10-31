--- @meta
--- @diagnostic disable

--- Aggregated EmmyLua annotations for the Mod Configuration Menu (MCM) public API.

---@class MCMGetArgs
---@field settingId string The ID of the setting to retrieve
---@field modUUID? string Optional mod UUID, defaults to current mod

---@class MCMSetArgs
---@field settingId string The ID of the setting to update
---@field value any The new value to set
---@field modUUID? string Optional mod UUID, defaults to current mod
---@field shouldEmitEvent? boolean Whether to emit a setting changed event

---@class MCMKeybindingGetArgs
---@field settingId string The ID of the keybinding setting
---@field modUUID? string Optional mod UUID, defaults to current mod

---@class MCMKeybindingSetCallbackArgs
---@field settingId string The ID of the keybinding setting
---@field callback fun(modUUID:string?, settingId:string) Callback function invoked when the keybinding is pressed
---@field modUUID? string Optional mod UUID, defaults to current mod

---@class MCMListGetArgs
---@field listSettingId string The ID of the list setting
---@field modUUID? string Optional mod UUID, defaults to current mod

---@class MCMListIsEnabledArgs
---@field listSettingId string The ID of the list setting
---@field itemName string The name of the item to check
---@field modUUID? string Optional mod UUID, defaults to current mod

---@class MCMListSetEnabledArgs
---@field listSettingId string The ID of the list setting
---@field itemName string The name of the item to update
---@field enabled boolean Whether the item should be enabled
---@field modUUID? string Optional mod UUID, defaults to current mod
---@field shouldEmitEvent? boolean Whether to emit a setting changed event

---@class MCMListInsertSuggestionsArgs
---@field listSettingId string The ID of the list_v2 setting
---@field suggestions string[] Table of suggestion strings to display
---@field modUUID? string Optional mod UUID, defaults to current mod

---@class MCMEventButtonStateArgs
---@field buttonId string The ID of the event button
---@field modUUID? string Optional mod UUID, defaults to current mod

---@class MCMEventButtonFeedbackArgs
---@field buttonId string The ID of the event button
---@field message string The feedback message to display
---@field feedbackType MCMEventButtonFeedbackType The type of feedback (success, error, info, warning)
---@field modUUID? string Optional mod UUID, defaults to current mod
---@field durationInMs? number Duration to display feedback in milliseconds (default: 5000)

---@class MCMEventButtonCallbackArgs
---@field buttonId string The ID of the event button
---@field callback fun(buttonId:string, modUUID:string?) Callback function invoked when the button is clicked
---@field modUUID? string Optional mod UUID, defaults to current mod

---@class MCMEventButtonSetDisabledArgs
---@field buttonId string The ID of the event button
---@field disabled boolean Whether the button should be disabled
---@field tooltipText? string Optional tooltip text to show when disabled
---@field modUUID? string Optional mod UUID, defaults to current mod

---@class MCMOpenModPageArgs
---@field tabName string The name of the tab to open
---@field modUUID? string Optional mod UUID, defaults to current mod
---@field shouldEmitEvent? boolean Whether to emit the mod page open event

---@class MCMInsertModMenuTabArgs
---@field tabName string The name of the tab to be inserted
---@field tabCallback fun(tab:any) Callback function to create the tab content
---@field modUUID? string Optional mod UUID, defaults to current mod
---@field skipDisclaimer? boolean If true, skip the disclaimer and render tab content immediately

---@alias MCMEmptyArgs {}
---@alias MCMEventButtonFeedbackType "success"|"error"|"info"|"warning" Feedback type for event button notifications

---@class MCMEventButtonFeedbackTypes Predefined feedback type constants for event buttons
---@field SUCCESS "success" Success feedback type
---@field ERROR "error" Error feedback type
---@field INFO "info" Info feedback type
---@field WARNING "warning" Warning feedback type

---@class MCMKeybindingAPI Keybinding-related API methods
---@field Get fun(settingIdOrArgs:string|MCMKeybindingGetArgs, modUUID?:string):string Get a human-readable keybinding string (e.g., "[Ctrl] + [C]")
---@field GetRaw fun(settingIdOrArgs:string|MCMKeybindingGetArgs, modUUID?:string):table|nil Get the raw keybinding data structure
---@field SetCallback fun(settingIdOrArgs:string|MCMKeybindingSetCallbackArgs, callback?:fun(modUUID:string?, settingId:string), modUUID?:string):nil Register a callback for when the keybinding is pressed

---@class MCMListAPI List setting-related API methods
---@field GetEnabled fun(listSettingIdOrArgs:string|MCMListGetArgs, modUUID?:string):table<string, boolean> Get all enabled items in a list setting
---@field GetRaw fun(listSettingIdOrArgs:string|MCMListGetArgs, modUUID?:string):table|nil Get the raw list setting data structure
---@field IsEnabled fun(listSettingIdOrArgs:string|MCMListIsEnabledArgs, itemName?:string, modUUID?:string):boolean Check if a specific item is enabled
---@field SetEnabled fun(listSettingIdOrArgs:string|MCMListSetEnabledArgs, itemName?:string, enabled?:boolean, modUUID?:string, shouldEmitEvent?:boolean):boolean Update the enabled state of an item
---@field InsertSuggestions fun(listSettingIdOrArgs:string|MCMListInsertSuggestionsArgs, suggestions?:string[], modUUID?:string):boolean Insert search suggestions for a list_v2 setting

---@class MCMEventButtonAPI Event button-related API methods (client-only)
---@field FeedbackTypes MCMEventButtonFeedbackTypes Predefined feedback type constants
---@field IsEnabled fun(buttonIdOrArgs:string|MCMEventButtonStateArgs, modUUID?:string):boolean|nil Check if an event button is enabled
---@field ShowFeedback fun(buttonIdOrArgs:string|MCMEventButtonFeedbackArgs, message?:string, feedbackType?:MCMEventButtonFeedbackType, modUUID?:string, durationInMs?:number):boolean Display a feedback message on an event button
---@field RegisterCallback fun(buttonIdOrArgs:string|MCMEventButtonCallbackArgs, callback?:fun(buttonId:string, modUUID:string?), modUUID?:string):boolean Register a callback for button clicks
---@field UnregisterCallback fun(buttonIdOrArgs:string|MCMEventButtonStateArgs, modUUID?:string):boolean Unregister a button click callback
---@field SetDisabled fun(buttonIdOrArgs:string|MCMEventButtonSetDisabledArgs, disabled?:boolean, tooltipText?:string, modUUID?:string):boolean Enable or disable an event button

---@class MCMTable Table containing the Mod Configuration Menu (MCM) public API exposed to each mod.
---@field Get fun(settingIdOrArgs:string|MCMGetArgs, modUUID?:string):any Get the value of a setting
---@field Set fun(settingIdOrArgs:string|MCMSetArgs, value?:any, modUUID?:string, shouldEmitEvent?:boolean):boolean Set the value of a setting
---@field Keybinding MCMKeybindingAPI Keybinding-related methods
---@field List MCMListAPI List setting-related methods
---@field EventButton MCMEventButtonAPI Event button-related methods (client-only)
---@field OpenMCMWindow fun():nil Open the MCM window (client-only)
---@field CloseMCMWindow fun():nil Close the MCM window (client-only)
---@field OpenModPage fun(tabNameOrArgs:string|MCMOpenModPageArgs, modUUID?:string, shouldEmitEvent?:boolean):nil Open a mod page in the MCM (client-only)
---@field SetKeybindingCallback fun(settingIdOrArgs:string|MCMKeybindingSetCallbackArgs, callback?:fun(modUUID:string?, settingId:string), modUUID?:string):nil Deprecated: use Keybinding.SetCallback instead
---@field GetList fun(listSettingIdOrArgs:string|MCMListGetArgs, modUUID?:string):table<string, boolean> Deprecated: use List.GetEnabled instead
---@field SetListElement fun(listSettingIdOrArgs:string|MCMListSetEnabledArgs, itemName?:string, enabled?:boolean, modUUID?:string, shouldEmitEvent?:boolean):boolean Deprecated: use List.SetEnabled instead

---@type MCMTable Table containing the MCM public API exposed to each mod.
MCM = {
    Keybinding = {},
    List = {},
    EventButton = { FeedbackTypes = {} }
}
