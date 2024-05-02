SubscribedEvents = {}

function SubscribedEvents.SubscribeToEvents()
    -- When resetting Lua states
    -- Ext.Events.ResetCompleted:Subscribe(EHandlers.OnReset)

    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "before", EHandlers.OnLevelGameplayStarted)
    --- Message handler for when the (IMGUI) client requests the MCM settings to be loaded
    Ext.RegisterNetListener(Channels.MCM_CLIENT_REQUEST_CONFIGS, EHandlers.OnClientRequestConfigs)
    Ext.RegisterConsoleCommand('mcm_reset', function() MCM:LoadAndSendSettings() end)

    --- Message handler for when the (IMGUI) client requests a setting to be set
    Ext.RegisterNetListener(Channels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE, EHandlers.OnClientRequestSetSettingValue)

    --- Message handler for when the (IMGUI) client requests a setting to be reset
    Ext.RegisterNetListener(Channels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE,
        EHandlers.OnClientRequestResetSettingValue)

    --- Message handler for when the (IMGUI) client requests a profile to be set
    Ext.RegisterNetListener(Channels.MCM_CLIENT_REQUEST_SET_PROFILE, EHandlers.OnClientRequestSetProfile)
end

return SubscribedEvents
