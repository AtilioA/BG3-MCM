SubscribedEvents = {}

local netEventsRegistry = CommandRegistry:new()

netEventsRegistry:register(Channels.MCM_CLIENT_REQUEST_CONFIGS, NetCommand:new(EHandlers.OnClientRequestConfigs))
netEventsRegistry:register(Channels.MCM_USER_OPENED_WINDOW, NetCommand:new(EHandlers.OnUserOpenedWindow))
netEventsRegistry:register(Channels.MCM_USER_CLOSED_WINDOW, NetCommand:new(EHandlers.OnUserClosedWindow))

--- Authorized NetCommand interface (inherits from NetCommand, check if user can edit settings etc)
netEventsRegistry:register(Channels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestSetSettingValue))
netEventsRegistry:register(Channels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestResetSettingValue))
-- registry:register(Channels.MCM_CLIENT_REQUEST_PROFILES, AuthorizedCommand:new(EHandlers.OnClientRequestProfiles))
netEventsRegistry:register(Channels.MCM_CLIENT_REQUEST_SET_PROFILE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestSetProfile))
netEventsRegistry:register(Channels.MCM_CLIENT_REQUEST_CREATE_PROFILE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestCreateProfile))
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
    if Config:getCfg().DEBUG.level > 2 then
        TestSuite.RunTests()
    end

    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "before", EHandlers.OnLevelGameplayStarted)


    registerNetListeners(netEventsRegistry)
end

return SubscribedEvents
