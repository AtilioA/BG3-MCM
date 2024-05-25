SubscribedEvents = {}

local netEventsRegistry = CommandRegistry:new()

--- Net message handler for when the (IMGUI) client requests the MCM settings to be loaded
netEventsRegistry:register(Channels.MCM_CLIENT_REQUEST_CONFIGS, NetCommand:new(EHandlers.OnClientRequestConfigs))
--- Net message handlers for when the (IMGUI) client opens or closes the MCM window
netEventsRegistry:register(Channels.MCM_USER_OPENED_WINDOW, NetCommand:new(EHandlers.OnUserOpenedWindow))
netEventsRegistry:register(Channels.MCM_USER_CLOSED_WINDOW, NetCommand:new(EHandlers.OnUserClosedWindow))

--- Authorized NetCommand interface (inherits from NetCommand, check if user can edit settings etc)
--- Net message handler for when the (IMGUI) client requests a setting to be set
netEventsRegistry:register(Channels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestSetSettingValue))
netEventsRegistry:register(Channels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestResetSettingValue))

--- Net message handler for when the (IMGUI) client requests profiles data
-- registry:register(Channels.MCM_CLIENT_REQUEST_PROFILES, AuthorizedCommand:new(EHandlers.OnClientRequestProfiles))

--- Net message handler for when the (IMGUI) client requests a profile to be set
netEventsRegistry:register(Channels.MCM_CLIENT_REQUEST_SET_PROFILE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestSetProfile))

--- Net message handler for when the (IMGUI) client requests a profile to be created
netEventsRegistry:register(Channels.MCM_CLIENT_REQUEST_CREATE_PROFILE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestCreateProfile))

--- Net message handler for when the (IMGUI) client requests a profile to be deleted
netEventsRegistry:register(Channels.MCM_CLIENT_REQUEST_DELETE_PROFILE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestDeleteProfile))

local function registerNetListeners(registry)
    local function handleNetMessage(channel, payload, peerId)
        registry:execute(channel, payload, peerId)
    end

    for channel, _ in pairs(registry.commands) do
        Ext.RegisterNetListener(channel, handleNetMessage)
    end
end


-- Subscribe to events
function SubscribedEvents.SubscribeToEvents()
    -- When resetting Lua states
    -- Ext.Events.ResetCompleted:Subscribe(EHandlers.OnReset)

    -- When the game is started, load the MCM settings
    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "before", EHandlers.OnLevelGameplayStarted)

    Ext.Events.SessionLoaded:Subscribe(EHandlers.OnSessionLoaded)

    registerNetListeners(netEventsRegistry)
end

return SubscribedEvents
