-- TODO: modularize this
Ext.Require("Shared/_Init.lua")
Ext.Require("Client/_Init.lua")

IMGUI_WINDOW = Ext.IMGUI.NewWindow("Mod Configuration Menu")
IMGUI_WINDOW.Visible = true

IMGUI_WINDOW:SetColor("Border", Color.normalized_rgba(0, 0, 0, 1))
IMGUI_WINDOW:SetStyle("WindowBorderSize", 2)
IMGUI_WINDOW:SetStyle("WindowRounding", 2)

-- Set the window background color
IMGUI_WINDOW:SetColor("TitleBg", Color.normalized_rgba(36, 28, 68, 0.5))
IMGUI_WINDOW:SetColor("TitleBgActive", Color.normalized_rgba(36, 28, 68, 1))

IMGUI_WINDOW:SetStyle("ScrollbarSize", 10)

-- Toggle the window with the INSERT key.
-- TODO: Modularize and make it configurable
Ext.Events.KeyInput:Subscribe(function(e)
    if e.Event == "KeyDown" and e.Repeat == false then
        if (e.Key == "INSERT" or e.Key == "APPLICATION") then
            IMGUI_WINDOW.Visible = not IMGUI_WINDOW.Visible
            IMGUI_WINDOW.Open = not IMGUI_WINDOW.Open
        end
    end
end)

-- TODO: add stuff to the menu bar
m = IMGUI_WINDOW:AddMainMenu()

options = m:AddMenu("Options")
options:AddItem("Adjust Setting 1").OnClick = function()
    MCMDebug(2, "Adjusting setting 1")
end
options:AddItem("Reset to Defaults").OnClick = function()
    MCMDebug(2, "Resetting options to defaults")
end

help = m:AddMenu("Help")
help:AddItem("About").OnClick = function()
    -- Code to show about information
    MCMDebug(2, "Showing about information")
end
help:AddItem("Troubleshooting").OnClick = function()
    -- Code to show troubleshooting information
    MCMDebug(2, "Showing troubleshooting information")
end

IMGUI_WINDOW.MenuBar = true

ClientGlobals = {
    MOD_SETTINGS = {}
}

Ext.Events.ResetCompleted:Subscribe(function()
    Ext.Net.PostMessageToServer("MCM_Client_Request_Settings", Ext.Json.Stringify({
        message = "Client reset has completed. Requesting MCM settings from server."
    }))
    IMGUI_WINDOW.Visible = true
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
    IMGUI_WINDOW.Visible = true
end)

Ext.RegisterNetListener("MCM_Relay_To_Servers", function(_, metapayload)
    local data = Ext.Json.Parse(metapayload)
    Ext.Net.PostMessageToServer(data.channel, Ext.Json.Stringify(data.payload))
end)

Ext.RegisterNetListener("MCM_Setting_Reset", function(_, payload)
    local data = Ext.Json.Parse(payload)
    local modGUID = data.modGUID
    local settingId = data.settingId
    local defaultValue = data.defaultValue

    -- Update the displayed value for the setting
    IMGUIAPI:UpdateSettingUIValue(modGUID, settingId, defaultValue)
end)

Ext.RegisterNetListener("MCM_Setting_Updated", function(_, payload)
    local data = Ext.Json.Parse(payload)
    local modGUID = data.modGUID
    local settingId = data.settingId
    local defaultValue = data.defaultValue

    -- Update the displayed value for the setting
    IMGUIAPI:UpdateSettingUIValue(modGUID, settingId, defaultValue)
end)
