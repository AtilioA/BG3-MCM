Ext.Require("Shared/_Init.lua")
Ext.Require("Client/_Init.lua")


IMGUI_WINDOW = Ext.IMGUI.NewWindow("Mod Configuration Menu")
IMGUI_WINDOW.Closeable = true
IMGUI_WINDOW.Visible = true
ClientGlobals = {
    MOD_SETTINGS = {}
}
