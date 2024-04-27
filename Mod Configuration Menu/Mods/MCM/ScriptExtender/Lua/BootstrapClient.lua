-- TODO: modularize this
Ext.Require("Shared/_Init.lua")
Ext.Require("Client/_Init.lua")

IMGUI_WINDOW = Ext.IMGUI.NewWindow("Mod Configuration Menu")
IMGUI_WINDOW.Closeable = true
IMGUI_WINDOW.Visible = true
-- TODO: add stuff to the menu bar when Norbyte adds support for it
-- lmao he already did it
-- m = w:AddMainMenu()
-- m1 = m:AddMenu("yo volly")
-- m1:AddItem("aaaaaaaaa")
-- m1:AddItem("bbbbbbbbb")
IMGUI_WINDOW.MenuBar = true

ClientGlobals = {
    MOD_SETTINGS = {}
}

Ext.Events.ResetCompleted:Subscribe(function()
    Ext.Net.PostMessageToServer("MCM_Settings_Request", Ext.Json.Stringify({
        message = "Client reset has completed. Requesting MCM settings from server."
    }))
end)

Ext.RegisterNetListener("MCM_Server_Send_Settings_To_Client", function(_, payload)
    ClientGlobals.MOD_SETTINGS = Ext.Json.Parse(payload)
    local mods = ClientGlobals.MOD_SETTINGS.mods
    local profiles = ClientGlobals.MOD_SETTINGS.profiles

    MCM_IMGUI_API:CreateModMenu(mods, profiles)

    -- Insert a new tab now that the MCM is ready
    MCM_IMGUI_API:InsertModMenuTab(ModuleUUID, "Inserted tab", function(tabHeader)
        local myCustomWidget = tabHeader:AddButton("My Custom Widget")
        myCustomWidget.OnClick = function()
            IMGUIAPI:SetConfigValue("my_custom_setting", "new_value", ModuleUUID)
        end
    end)
end)

Ext.RegisterNetListener("MCM_Relay_To_Servers", function(_, metapayload)
    local data = Ext.Json.Parse(metapayload)
    Ext.Net.PostMessageToServer(data.channel, Ext.Json.Stringify(data.payload))
end)
