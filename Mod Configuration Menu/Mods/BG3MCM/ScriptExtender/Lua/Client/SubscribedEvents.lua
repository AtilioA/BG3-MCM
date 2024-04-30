--- SECTION: Ext events

-- Toggle the window with the insert and context menu key.
-- TODO: Make it more abstract/7configurable
Ext.Events.KeyInput:Subscribe(function(e)
    if e.Event == "KeyDown" and e.Repeat == false then
        if (e.Key == "INSERT" or e.Key == "APPLICATION") then
            IMGUI_WINDOW.Visible = not IMGUI_WINDOW.Visible
            IMGUI_WINDOW.Open = not IMGUI_WINDOW.Open
        end
    end
end)

Ext.Events.ResetCompleted:Subscribe(function()
    Ext.Net.PostMessageToServer("MCM_Client_Request_Settings", Ext.Json.Stringify({
        message = "Client reset has completed. Requesting MCM settings from server."
    }))
    IMGUI_WINDOW.Visible = true
end)

--- SECTION: Net listeners

Ext.RegisterNetListener("MCM_Server_Send_Settings_To_Client", function(_, payload)
    ClientGlobals.MOD_SETTINGS = Ext.Json.Parse(payload)
    local mods = ClientGlobals.MOD_SETTINGS.mods
    local profiles = ClientGlobals.MOD_SETTINGS.profiles

    -- shit why did I name it like this
    MCM_IMGUI_LAYER:CreateModMenu(mods, profiles)

    -- Insert a new tab now that the MCM is ready (demonstration)
    IMGUIAPI:InsertModMenuTab(ModuleUUID, "Inserted tab", function(tabHeader)
        local myCustomWidget = tabHeader:AddButton("My Custom Widget")
        myCustomWidget.OnClick = function()
            _D("My custom widget was clicked!")
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

Ext.RegisterNetListener("MCM_Mod_Tab_Added", function(_, payload)
    local data = Ext.Json.Parse(payload)
    local modGUID = data.modGUID
    local tabName = data.tabName
    local tabCallback = data.tabCallback

    -- Update the IMGUILayer to include the new tab
    IMGUIAPI:InsertModMenuTab(modGUID, tabName, tabCallback)
end)

Ext.RegisterNetListener("MCM_Server_Set_Profile", function(_, payload)
    local data = Ext.Json.Parse(payload)
    local newSettings = data.newSettings

    for modGUID, modSettings in pairs(newSettings) do
        for settingId, settingValue in pairs(modSettings.settingsValues) do
            IMGUIAPI:UpdateSettingUIValue(modGUID, settingId, settingValue)
        end
    end
end)
