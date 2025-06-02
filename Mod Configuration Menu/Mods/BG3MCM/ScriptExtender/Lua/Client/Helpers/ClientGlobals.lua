ClientGlobals = {}

-- UI Icons
ClientGlobals.RESET_SETTING_BUTTON_ICON = "ico_randomize_d"

-- Special page IDs
---@class SpecialPages
---@field MCM_HOTKEYS string The hotkeys page ID
---@field MCM_PROFILES string The profiles page ID
---@field MCM_DYNAMIC_SETTINGS string The dynamic settings page ID
ClientGlobals.SPECIAL_PAGES = {
  MCM_HOTKEYS = Ext.Loca.GetTranslatedString("h1574a7787caa4e5f933e2f03125a539c1139"),
  MCM_PROFILES = Ext.Loca.GetTranslatedString("h2082b6b6954741ef970486be3bb77ad53782"),
  MCM_DYNAMIC_SETTINGS = Ext.Loca.GetTranslatedString("haa412174bc3e45a4a43dc88f7877df8409d3")
}

-- If no tab is found inserted within 10 seconds
ClientGlobals.MCM_RESTORATION_MOD_TAB_INSERTED_TIMEOUT = 1000 * 10

return ClientGlobals
