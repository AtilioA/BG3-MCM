SubscribedEvents = {}

function SubscribedEvents.SubscribeToEvents()
    -- When resetting Lua states
    -- Ext.Events.ResetCompleted:Subscribe(EHandlers.OnReset)
    if Config:getCfg().DEBUG.level > 2 then
        TestSuite.RunTests()
    end

    -- When the game is started, load the MCM settings
    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "before", EHandlers.OnLevelGameplayStarted)

    --- Message handler for when the (IMGUI) client requests the MCM settings to be loaded
    Ext.RegisterNetListener(Channels.MCM_CLIENT_REQUEST_CONFIGS, EHandlers.OnClientRequestConfigs)

    --- Message handler for when the (IMGUI) client requests a setting to be set
    Ext.RegisterNetListener(Channels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE, EHandlers.OnClientRequestSetSettingValue)

    --- Message handler for when the (IMGUI) client requests a setting to be reset
    Ext.RegisterNetListener(Channels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE,
        EHandlers.OnClientRequestResetSettingValue)

    --- Message handler for when the (IMGUI) client requests a profile to be set
    Ext.RegisterNetListener(Channels.MCM_CLIENT_REQUEST_SET_PROFILE, EHandlers.OnClientRequestSetProfile)

    --- Message handler for when the (IMGUI) client opens or closes the MCM window
    Ext.RegisterNetListener(Channels.MCM_USER_OPENED_WINDOW, EHandlers.OnUserOpenedWindow)
    Ext.RegisterNetListener(Channels.MCM_USER_CLOSED_WINDOW, EHandlers.OnUserClosedWindow)
end

return SubscribedEvents
