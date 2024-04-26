-- Ext.Require("Shared/_Init.lua")
Ext.Require("Client/_Init.lua")

IMGUI_WINDOW = Ext.IMGUI.NewWindow("Mod Configuration Menu")
IMGUI_WINDOW.Closeable = true
IMGUI_WINDOW.Visible = true
-- TODO: add stuff to the menu bar
IMGUI_WINDOW.MenuBar = true
ClientGlobals = {
    MOD_SETTINGS = {}
}

Ext.Events.ResetCompleted:Subscribe(function()
    Ext.Net.PostMessageToServer("MCM_Settings_Request", Ext.Json.Stringify({
        message = "Client reset has completed. Requesting MCM settings from server."
    }))
end)

Ext.RegisterNetListener("MCM_Settings_To_Client", function(_, payload)
    ClientGlobals.MOD_SETTINGS = Ext.Json.Parse(payload)
    local mods = ClientGlobals.MOD_SETTINGS.mods
    local profiles = ClientGlobals.MOD_SETTINGS.profiles

    IMGUILayer:CreateModMenu(mods, profiles)
end)

Ext.RegisterNetListener("MCM_Relay_To_Servers", function(_, metapayload)
    local data = Ext.Json.Parse(metapayload)
    Ext.Net.PostMessageToServer(data.channel, Ext.Json.Stringify(data.payload))
end)

-- function CreateModMenu()
--     IMGUI_WINDOW:AddInputText("Shrimple,", "Yet elusive :norb:")
-- end

-- Ext.RegisterNetListener("MCM_SetConfigValue", function(_, payload)
--     local data = Ext.Json.Parse(payload)
--     settings[data.modGUID].settings[data.settingName] = data.value
-- end)
