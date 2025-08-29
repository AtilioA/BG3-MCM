ClientGlobals = {}

-- UI Icons
ClientGlobals.RESET_SETTING_BUTTON_ICON = "ico_randomize_d"

-- Special page IDs
ClientGlobals.MCM_HOTKEYS = "MCM_HOTKEYS"
ClientGlobals.MCM_PROFILES = "MCM_PROFILES"

-- Localized strings
ClientGlobals.UNASSIGNED_KEYBOARD_MOUSE_STRING = Ext.Loca.GetTranslatedString("h08c75c996813442bb40fa085f1ecec07f14e")
ClientGlobals.LISTENING_INPUT_STRING = Ext.Loca.GetTranslatedString("h2ea690497b1a4ffea4b2ed480df3654c486f")

-- Timeouts
ClientGlobals.MCM_RESTORATION_MOD_TAB_INSERTED_TIMEOUT = 1000 * 10

-- Default duration for event button feedback in milliseconds
ClientGlobals.MCM_EVENT_BUTTON_FEEDBACK_DURATION = 5000

return ClientGlobals
