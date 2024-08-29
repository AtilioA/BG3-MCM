EventChannels = {}

--- Fired when a setting value has been updated.
--- @return string modUUID The UUID of the mod
--- @return string settingId The ID of the setting
--- @return any oldValue The old value of the setting
--- @return any value The new value of the setting
EventChannels.MCM_SAVED_SETTING = "MCM_Saved_Setting"
-- Deprecated: Use MCM_SAVED_SETTING instead
EventChannels.MCM_SETTING_UPDATED = "MCM_Setting_Updated"

--- Fired when a setting is reset to its default value.
--- @return string modUUID The UUID of the mod
--- @return string settingId The ID of the setting
--- @return any defaultValue The default value of the setting
EventChannels.MCM_SETTING_RESET = "MCM_Setting_Reset"

--- Fired when all mod settings are reset to their default values.
--- @return string modUUID The UUID of the mod
-- EventChannels.MCM_RESET_ALL_MOD_SETTINGS = "MCM_Reset_All_Mod_Settings"

--- Fired when a new profile is created.
--- @return string profileName The name of the created profile
--- @return table<string, table<string, any>> newSettings The settings of the new profile
EventChannels.MCM_CREATED_PROFILE = "MCM_Created_Profile"

-- TODO: complete docs for everything profile/tab related
--- Fired when a profile is set as the active one.
--- @return string profileName The name of the active profile
EventChannels.MCM_SET_PROFILE = "MCM_Set_Profile"

--- Fired when a profile is deleted.
--- @return string profileName The name of the deleted profile
EventChannels.MCM_DELETED_PROFILE = "MCM_Deleted_Profile"

--- Fired when a mod inserts a custom tab into the MCM UI.
--- @return string modUUID The UUID of the mod
--- @return string tabName The name of the tab added
EventChannels.MCM_MOD_TAB_ADDED = "MCM_Mod_Tab_Added"

--- Fired when the user clicks a mod in the mod list in MCM's left panel.
--- @return string modUUID The UUID of the mod
--- @return string tabName The name of the activated tab
--- @return ImguiHandle tabImguiObject The IMGUI object of the activated subtab
EventChannels.MCM_MOD_TAB_ACTIVATED = "MCM_Mod_Tab_Activated"

--- Fired when a subtab within a mod tab is activated.
--- @return string modUUID The UUID of the mod
--- @return string subtabName The name of the activated subtab
--- @return ImguiHandle subtabImguiObject The IMGUI object of the activated subtab
EventChannels.MCM_MOD_SUBTAB_ACTIVATED = "MCM_Mod_Subtab_Activated"

--- Fired when the MCM window is ready for interaction.
--- @return ExtuiTreeParent MCM_WINDOW The main window/root IMGUI object of MCM
EventChannels.MCM_WINDOW_READY = "MCM_Window_Ready"

--- This event is fired when a player opens the MCM window.
--- @return boolean playSound Whether a sound should be played when the window opens.
EventChannels.MCM_USER_OPENED_WINDOW = "MCM_User_Opened_Window"

--- Fired when a player closes the MCM window.
--- @return boolean playSound Whether a sound should be played when the window closes.
EventChannels.MCM_USER_CLOSED_WINDOW = "MCM_User_Closed_Window"

return EventChannels
