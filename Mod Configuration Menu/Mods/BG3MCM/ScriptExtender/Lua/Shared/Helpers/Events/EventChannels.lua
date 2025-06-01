EventChannels = {}

--- Fired when a setting value has been updated.
--- @return string modUUID The UUID of the mod
--- @return string settingId The ID of the setting
--- @return any oldValue The old value of the setting
--- @return any value The new value of the setting
EventChannels.MCM_SETTING_SAVED = "MCM_Setting_Saved"
-- REMOVED: Use MCM_SETTING_SAVED instead
-- EventChannels.MCM_SETTING_UPDATED = "MCM_Setting_Updated"
EventChannels.MCM_INTERNAL_SETTING_SAVED = "MCM_Internal_Setting_Saved"

--- Fired when a dynamic setting value has been updated.
--- @return string modUUID The UUID of the mod
--- @return string key The key ('id'/'name') of the setting
--- @return any oldValue The old value of the setting
--- @return any value The new value of the setting
--- @return string storageType The type of storage ("ModVar", "ModConfig", etc.)
EventChannels.MCM_DYNAMIC_SETTING_SAVED = "MCM_Dynamic_Setting_Saved"

--- Fired when a setting is reset to its default value.
--- @return string modUUID The UUID of the mod
--- @return string settingId The ID of the setting
--- @return any defaultValue The default value of the setting
EventChannels.MCM_SETTING_RESET = "MCM_Setting_Reset"

--- Fired when all mod settings are reset to their default values.
--- @return string modUUID The UUID of the mod
-- EventChannels.MCM_ALL_MOD_SETTINGS_RESET = "MCM_All_Mod_Settings_Reset"

--- Fired when a new profile is created.
--- @return string profileName The name of the created profile
--- @return table<string, table<string, any>> newSettings The settings of the new profile
EventChannels.MCM_PROFILE_CREATED = "MCM_Profile_Created"

-- TODO: complete docs for everything profile/tab related
--- Fired when a profile is set as the active one.
--- @return string profileName The name of the active profile
EventChannels.MCM_PROFILE_ACTIVATED = "MCM_Profile_Activated"

--- Fired when a profile is deleted.
--- @return string profileName The name of the deleted profile
EventChannels.MCM_PROFILE_DELETED = "MCM_Profile_Deleted"

--- Fired when a mod inserts a custom tab into the MCM UI.
--- @return string modUUID The UUID of the mod
--- @return string tabName The name of the tab added
EventChannels.MCM_MOD_TAB_ADDED = "MCM_Mod_Tab_Added"

--- Fired when the user clicks a mod in the mod list in MCM's left panel.
--- @return string modUUID The UUID of the mod
EventChannels.MCM_MOD_TAB_ACTIVATED = "MCM_Mod_Tab_Activated"

--- Fired when a subtab within a mod tab is activated.
--- @return string modUUID The UUID of the mod
--- @return string subtabName The name of the activated subtab
EventChannels.MCM_MOD_SUBTAB_ACTIVATED = "MCM_Mod_Subtab_Activated"

--- Fired when the MCM window is ready for interaction.
--- @return ExtuiTreeParent MCM_WINDOW The main window/root IMGUI object of MCM
EventChannels.MCM_WINDOW_READY = "MCM_Window_Ready"

--- This event is fired when a player opens the MCM window.
--- @return boolean playSound Whether a sound should be played when the window opens.
EventChannels.MCM_WINDOW_OPENED = "MCM_Window_Opened"

--- Fired when a player closes the MCM window.
--- @return boolean playSound Whether a sound should be played when the window closes.
EventChannels.MCM_WINDOW_CLOSED = "MCM_Window_Closed"

--- Fired when keybindings are loaded.
EventChannels.MCM_KEYBINDINGS_LOADED = "MCM_Keybindings_Loaded"

--- Fired when an event_button is clicked.
--- @return string modUUID The UUID of the mod
--- @return string settingId The ID of the event button setting
EventChannels.MCM_EVENT_BUTTON_CLICKED = "MCM_Event_Button_Clicked"

local function RegisterModEvents()
    local BG3DirName = Ext.Mod.GetMod(ModuleUUID).Info.Directory

    Ext.RegisterModEvent(BG3DirName, EventChannels.MCM_SETTING_SAVED)
    Ext.RegisterModEvent(BG3DirName, EventChannels.MCM_SETTING_RESET)
    Ext.RegisterModEvent(BG3DirName, EventChannels.MCM_PROFILE_CREATED)
    Ext.RegisterModEvent(BG3DirName, EventChannels.MCM_PROFILE_ACTIVATED)
    Ext.RegisterModEvent(BG3DirName, EventChannels.MCM_PROFILE_DELETED)
    Ext.RegisterModEvent(BG3DirName, EventChannels.MCM_MOD_TAB_ADDED)
    Ext.RegisterModEvent(BG3DirName, EventChannels.MCM_MOD_TAB_ACTIVATED)
    Ext.RegisterModEvent(BG3DirName, EventChannels.MCM_MOD_SUBTAB_ACTIVATED)
    Ext.RegisterModEvent(BG3DirName, EventChannels.MCM_WINDOW_READY)
    Ext.RegisterModEvent(BG3DirName, EventChannels.MCM_WINDOW_OPENED)
    Ext.RegisterModEvent(BG3DirName, EventChannels.MCM_WINDOW_CLOSED)
    Ext.RegisterModEvent(BG3DirName, EventChannels.MCM_KEYBINDINGS_LOADED)
    Ext.RegisterModEvent(BG3DirName, EventChannels.MCM_EVENT_BUTTON_CLICKED)
end

RegisterModEvents()

return EventChannels
