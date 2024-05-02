--- SECTION: Ext events

-- Toggle the window with the insert and context menu key.
-- TODO: Make it more abstract/configurable
Ext.Events.KeyInput:Subscribe(function(e)
    if e.Event == "KeyDown" and e.Repeat == false then
        if (e.Key == "INSERT" or e.Key == "APPLICATION") then
            IMGUI_WINDOW.Visible = not IMGUI_WINDOW.Visible
            IMGUI_WINDOW.Open = not IMGUI_WINDOW.Open
        end
    end
end)

Ext.Events.ResetCompleted:Subscribe(function()
    Ext.Net.PostMessageToServer(Channels.MCM_CLIENT_REQUEST_CONFIGS, Ext.Json.Stringify({
        message = "Client reset has completed. Requesting MCM settings from server."
    }))
    IMGUI_WINDOW.Visible = true
end)

--- SECTION: Net listeners

Ext.RegisterNetListener(Channels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT, function(_, payload)
    local configs = Ext.Json.Parse(payload)
    local mods = configs.mods
    local profiles = configs.profiles

    -- shit why did I name it like this
    MCM_IMGUI_LAYER:CreateModMenu(mods)

    -- Insert a new tab now that the MCM is ready (demonstration)
    IMGUIAPI:InsertModMenuTab(ModuleUUID, "Inserted tab", function(tabHeader)
        local myCustomWidget = tabHeader:AddButton("My Custom Widget")
        myCustomWidget.OnClick = function()
            _D("My custom widget was clicked!")
        end
    end)
    IMGUI_WINDOW.Visible = true
end)

Ext.RegisterNetListener(Channels.MCM_RELAY_TO_SERVERS, function(_, metapayload)
    local data = Ext.Json.Parse(metapayload)
    Ext.Net.PostMessageToServer(data.channel, Ext.Json.Stringify(data.payload))
end)

Ext.RegisterNetListener(Channels.MCM_SETTING_RESET, function(_, payload)
    local data = Ext.Json.Parse(payload)
    local modGUID = data.modGUID
    local settingId = data.settingId
    local defaultValue = data.defaultValue

    -- Update the displayed value for the setting
    IMGUIAPI:UpdateSettingUIValue(modGUID, settingId, defaultValue)
end)

Ext.RegisterNetListener(Channels.MCM_SETTING_UPDATED, function(_, payload)
    local data = Ext.Json.Parse(payload)
    local modGUID = data.modGUID
    local settingId = data.settingId
    local defaultValue = data.defaultValue

    -- Update the displayed value for the setting
    IMGUIAPI:UpdateSettingUIValue(modGUID, settingId, defaultValue)
end)

Ext.RegisterNetListener(Channels.MCM_MOD_TAB_ADDED, function(_, payload)
    local data = Ext.Json.Parse(payload)
    local modGUID = data.modGUID
    local tabName = data.tabName
    local tabCallback = data.tabCallback

    -- Update the IMGUILayer to include the new tab
    IMGUIAPI:InsertModMenuTab(modGUID, tabName, tabCallback)
end)

Ext.RegisterNetListener(Channels.MCM_SERVER_SET_PROFILE, function(_, payload)
    local data = Ext.Json.Parse(payload)
    local newSettings = data.newSettings

    for modGUID, modSettings in pairs(newSettings) do
        for settingId, settingValue in pairs(modSettings.settingsValues) do
            IMGUIAPI:UpdateSettingUIValue(modGUID, settingId, settingValue)
        end
    end
end)
