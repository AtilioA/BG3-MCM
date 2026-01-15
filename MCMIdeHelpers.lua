--- @meta
--- @diagnostic disable

--- Aggregated EmmyLua annotations for the Mod Configuration Menu (MCM) public API (version 1.38+).

---@class MCMGetArgs
---@field settingId string The ID of the setting to retrieve
---@field modUUID? string Optional mod UUID, defaults to caller mod

---@class MCMSetArgs
---@field settingId string The ID of the setting to update
---@field value any The new value to set
---@field modUUID? string Optional mod UUID, defaults to caller mod
---@field shouldEmitEvent? boolean Whether to emit a setting changed event

---@class MCMKeybindingGetArgs
---@field settingId string The ID of the keybinding setting
---@field modUUID? string Optional mod UUID, defaults to caller mod

---@class MCMKeybindingSetCallbackArgs
---@field settingId string The ID of the keybinding setting
---@field callback fun(modUUID:string?, settingId:string) Callback function invoked when the keybinding is pressed
---@field modUUID? string Optional mod UUID, defaults to caller mod

---@class MCMListGetArgs
---@field listSettingId string The ID of the list setting
---@field modUUID? string Optional mod UUID, defaults to caller mod

---@class MCMListIsEnabledArgs
---@field listSettingId string The ID of the list setting
---@field itemName string The name of the item to check
---@field modUUID? string Optional mod UUID, defaults to caller mod

---@class MCMListSetEnabledArgs
---@field listSettingId string The ID of the list setting
---@field itemName string The name of the item to update
---@field enabled boolean Whether the item should be enabled
---@field modUUID? string Optional mod UUID, defaults to caller mod
---@field shouldEmitEvent? boolean Whether to emit a setting changed event

---@class MCMListInsertSuggestionsArgs
---@field listSettingId string The ID of the list_v2 setting
---@field suggestions string[] Table of suggestion strings to display
---@field modUUID? string Optional mod UUID, defaults to caller mod

---@class MCMEventButtonStateArgs
---@field buttonId string The ID of the event button
---@field modUUID? string Optional mod UUID, defaults to caller mod

---@class MCMEventButtonFeedbackArgs
---@field buttonId string The ID of the event button
---@field message string The feedback message to display
---@field feedbackType MCMEventButtonFeedbackType The type of feedback (success, error, info, warning)
---@field modUUID? string Optional mod UUID, defaults to caller mod
---@field durationInMs? number Duration to display feedback in milliseconds (default: 5000)

---@class MCMEventButtonCallbackArgs
---@field buttonId string The ID of the event button
---@field callback fun(buttonId:string, modUUID:string?) Callback function invoked when the button is clicked
---@field modUUID? string Optional mod UUID, defaults to caller mod

---@class MCMEventButtonSetDisabledArgs
---@field buttonId string The ID of the event button
---@field disabled boolean Whether the button should be disabled
---@field tooltipText? string Optional tooltip text to show when disabled
---@field modUUID? string Optional mod UUID, defaults to caller mod

---@class MCMOpenModPageArgs
---@field tabName string The name of the tab to open
---@field modUUID? string Optional mod UUID, defaults to caller mod
---@field shouldEmitEvent? boolean Whether to emit the mod page open event

---@class MCMInsertModMenuTabArgs
---@field tabName string The name of the tab to be inserted/add content to
---@field tabCallback fun(tab:any) Callback function to create the tab content
---@field modUUID? string Optional mod UUID, defaults to caller mod
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

---@class MCMStoreRegisterArgs
---@field var string The name/key of the variable to register
---@field default? any The default value for the variable
---@field type? string Optional type hint ("boolean", "number", "string", "table")
---@field storage? string Optional storage type ("json", etc.), defaults to "json". Only json storage is implemented at the moment
---@field validate? fun(value: any): (boolean, string)? Optional validation function
---@field modUUID? string Optional mod UUID, defaults to caller mod

---@class MCMStoreGetArgs
---@field var string The name/key of the variable to retrieve
---@field modUUID? string Optional mod UUID, defaults to caller mod

---@class MCMStoreSetArgs
---@field var string The name/key of the variable to set
---@field value any The value to set
---@field modUUID? string Optional mod UUID, defaults to caller mod

---@class MCMStoreGetAllArgs
---@field modUUID? string Optional mod UUID, defaults to caller mod
---@field storage? string Optional storage type, defaults to "json". Only json storage is implemented at the moment

---@class MCMStoreAPI Store API for JSON persistence of non-blueprint settings
---@field Register fun(varOrArgs:string|MCMStoreRegisterArgs, default?:any, type?:string, storage?:string, modUUID?:string):boolean Register a variable for JSON persistence
---@field Get fun(varNameOrArgs:string|MCMStoreGetArgs, modUUID?:string):any Get a stored value
---@field Set fun(varNameOrArgs:string|MCMStoreSetArgs, value?:any, modUUID?:string):boolean Set a stored value
---@field GetAll fun(modUUIDOrArgs?:string|MCMStoreGetAllArgs):table<string, any> Get all stored values for this mod

---@class MCMTable Table containing the Mod Configuration Menu (MCM) public API exposed to each mod.
---@field Get fun(settingIdOrArgs:string|MCMGetArgs, modUUID?:string):any Get the value of a setting
---@field Set fun(settingIdOrArgs:string|MCMSetArgs, value?:any, modUUID?:string, shouldEmitEvent?:boolean):boolean Set the value of a setting
---@field Keybinding MCMKeybindingAPI Keybinding-related methods
---@field List MCMListAPI List setting-related methods
---@field EventButton MCMEventButtonAPI Event button-related methods (client-only)
---@field Store MCMStoreAPI Store API for JSON persistence of non-blueprint settings
---@field OpenMCMWindow fun():nil Open the MCM window (client-only)
---@field CloseMCMWindow fun():nil Close the MCM window (client-only)
---@field InsertModMenuTab fun(tabNameOrArgs:string|MCMInsertModMenuTabArgs, tabCallback?:fun(tab:any), modUUID?:string, skipDisclaimer?:boolean):nil Insert a new tab into the MCM (client-only)
---@field OpenModPage fun(tabNameOrArgs:string|MCMOpenModPageArgs, modUUID?:string, shouldEmitEvent?:boolean):nil Open a mod page in the MCM (client-only)

---@type MCMTable Table containing the MCM public API exposed to each mod.
MCM = {
    Keybinding = {},
    List = {},
    EventButton = { FeedbackTypes = {} },
    Store = {}
}

--- @class MCM_Setting_Saved_Payload
--- @field modUUID string The UUID of the mod
--- @field settingId string The ID of the setting
--- @field oldValue any The old value of the setting
--- @field value any The new value of the setting

--- @class MCM_Setting_Reset_Payload
--- @field modUUID string The UUID of the mod
--- @field settingId string The ID of the setting
--- @field defaultValue any The default value of the setting

--- Note: still unused by MCM
--- @class MCM_Dynamic_Setting_Saved_Payload
--- @field modUUID string The UUID of the mod
--- @field key string The key ('id'/'name') of the setting
--- @field oldValue any The old value of the setting
--- @field value any The new value of the setting
--- @field storage string The type of storage ("ModVar", "ModConfig", etc.)

--- @class MCM_Profile_Created_Payload
--- @field profileName string The name of the created profile
--- @field newSettings table<string, table<string, any>> The settings of the new profile

--- @class MCM_Profile_Activated_Payload
--- @field profileName string The name of the active profile

--- @class MCM_Profile_Deleted_Payload
--- @field profileName string The name of the deleted profile

--- @class MCM_Mod_Tab_Added_Payload
--- @field modUUID string The UUID of the mod that owns the tab
--- @field tabName string The name of the tab added

--- @class MCM_Mod_Tab_Activated_Payload
--- @field modUUID string The UUID of the mod that owns the menu

--- @class MCM_Mod_Subtab_Activated_Payload
--- @field modUUID string The UUID of the mod that owns the tab
--- @field subtabName string The name of the activated subtab

--- @class MCM_Window_Ready_Payload
--- @field MCM_WINDOW ExtuiWindow The main window/root IMGUI object of MCM

--- @class MCM_Window_Opened_Payload
--- @field playSound boolean Whether a sound should be played when the window opens

--- @class MCM_Window_Closed_Payload
--- @field playSound boolean Whether a sound should be played when the window closes

--- @class MCM_Event_Button_Clicked_Payload
--- @field modUUID string The UUID of the mod
--- @field settingId string The ID of the event button setting

--- @class ModEvent_MCM_Setting_Saved
--- @field Subscribe fun(self: ModEvent_MCM_Setting_Saved, callback: fun(payload: MCM_Setting_Saved_Payload))

--- @class ModEvent_MCM_Setting_Reset
--- @field Subscribe fun(self: ModEvent_MCM_Setting_Reset, callback: fun(payload: MCM_Setting_Reset_Payload))

--- @class ModEvent_MCM_Dynamic_Setting_Saved
--- @field Subscribe fun(self: ModEvent_MCM_Dynamic_Setting_Saved, callback: fun(payload: MCM_Dynamic_Setting_Saved_Payload))

--- @class ModEvent_MCM_Profile_Created
--- @field Subscribe fun(self: ModEvent_MCM_Profile_Created, callback: fun(payload: MCM_Profile_Created_Payload))

--- @class ModEvent_MCM_Profile_Activated
--- @field Subscribe fun(self: ModEvent_MCM_Profile_Activated, callback: fun(payload: MCM_Profile_Activated_Payload))

--- @class ModEvent_MCM_Profile_Deleted
--- @field Subscribe fun(self: ModEvent_MCM_Profile_Deleted, callback: fun(payload: MCM_Profile_Deleted_Payload))

--- @class ModEvent_MCM_Mod_Tab_Added
--- @field Subscribe fun(self: ModEvent_MCM_Mod_Tab_Added, callback: fun(payload: MCM_Mod_Tab_Added_Payload))

--- @class ModEvent_MCM_Mod_Tab_Activated
--- @field Subscribe fun(self: ModEvent_MCM_Mod_Tab_Activated, callback: fun(payload: MCM_Mod_Tab_Activated_Payload))

--- @class ModEvent_MCM_Mod_Subtab_Activated
--- @field Subscribe fun(self: ModEvent_MCM_Mod_Subtab_Activated, callback: fun(payload: MCM_Mod_Subtab_Activated_Payload))

--- @class ModEvent_MCM_Window_Ready
--- @field Subscribe fun(self: ModEvent_MCM_Window_Ready, callback: fun(payload: MCM_Window_Ready_Payload))

--- @class ModEvent_MCM_Window_Opened
--- @field Subscribe fun(self: ModEvent_MCM_Window_Opened, callback: fun(payload: MCM_Window_Opened_Payload))

--- @class ModEvent_MCM_Window_Closed
--- @field Subscribe fun(self: ModEvent_MCM_Window_Closed, callback: fun(payload: MCM_Window_Closed_Payload))

--- @class ModEvent_MCM_Event_Button_Clicked
--- @field Subscribe fun(self: ModEvent_MCM_Event_Button_Clicked, callback: fun(payload: MCM_Event_Button_Clicked_Payload))

--- @class ModEvent_Generic
--- @field Subscribe fun(self: ModEvent_Generic, callback: fun(payload: any))

--- @class BG3MCM_ModEvents
--- @field MCM_Setting_Saved ModEvent_MCM_Setting_Saved
--- @field MCM_Internal_Setting_Saved ModEvent_Generic
--- @field MCM_Dynamic_Setting_Saved ModEvent_MCM_Dynamic_Setting_Saved
--- @field MCM_Setting_Reset ModEvent_MCM_Setting_Reset
-- - @field MCM_Profile_Created ModEvent_MCM_Profile_Created
--- @field MCM_Profile_Activated ModEvent_MCM_Profile_Activated
-- - @field MCM_Profile_Deleted ModEvent_MCM_Profile_Deleted
--- @field MCM_Mod_Tab_Added ModEvent_MCM_Mod_Tab_Added
--- @field MCM_Mod_Tab_Activated ModEvent_MCM_Mod_Tab_Activated
--- @field MCM_Mod_Subtab_Activated ModEvent_MCM_Mod_Subtab_Activated
--- @field MCM_Window_Ready ModEvent_MCM_Window_Ready
--- @field MCM_Window_Opened ModEvent_MCM_Window_Opened
--- @field MCM_Window_Closed ModEvent_MCM_Window_Closed
--- @field MCM_Keybindings_Loaded ModEvent_Generic
--- @field MCM_Event_Button_Clicked ModEvent_MCM_Event_Button_Clicked

--- @class ExtModEvents
--- @field BG3MCM BG3MCM_ModEvents

--- @type ExtModEvents
Ext.ModEvents = Ext.ModEvents or {}
