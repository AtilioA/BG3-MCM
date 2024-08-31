SubscribedEvents = {}

local netEventsRegistry = CommandRegistry:new()
local modEventRegistry = CommandRegistry:new()

--- Net message handler for when the (IMGUI) client requests the MCM settings to be loaded
netEventsRegistry:register(NetChannels.MCM_CLIENT_REQUEST_CONFIGS, NetCommand:new(EHandlers.OnClientRequestConfigs))

--- Net message handler to relay messages to other clients (backwards support for deprecated net message usage)
netEventsRegistry:register(NetChannels.MCM_RELAY_TO_CLIENTS, NetCommand:new(EHandlers.OnRelayToClients))

--- Net message handlers for when the (IMGUI) client opens or closes the MCM window
modEventRegistry:register(EventChannels.MCM_WINDOW_OPENED, EHandlers.OnUserOpenedWindow)
modEventRegistry:register(EventChannels.MCM_WINDOW_CLOSED, EHandlers.OnUserClosedWindow)

--- Net message handler for when the user spams the MCM button (the window is probably not open)
netEventsRegistry:register(NetChannels.MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION,
    NetCommand:new(EHandlers.OnUserSpamMCMButton))

--- Authorized NetCommand interface (inherits from NetCommand, check if user can edit settings etc)
--- Net message handler for when the (IMGUI) client requests a setting to be set
netEventsRegistry:register(NetChannels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestSetSettingValue))
netEventsRegistry:register(NetChannels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestResetSettingValue))

--- Net message handler for when the (IMGUI) client requests profiles data
-- registry:register(NetChannels.MCM_CLIENT_REQUEST_PROFILES, AuthorizedCommand:new(EHandlers.OnClientRequestProfiles))

--- Net message handler for when the (IMGUI) client requests a profile to be set
netEventsRegistry:register(NetChannels.MCM_CLIENT_REQUEST_SET_PROFILE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestSetProfile))

--- Net message handler for when the (IMGUI) client requests a profile to be created
netEventsRegistry:register(NetChannels.MCM_CLIENT_REQUEST_CREATE_PROFILE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestCreateProfile))

--- Net message handler for when the (IMGUI) client requests a profile to be deleted
netEventsRegistry:register(NetChannels.MCM_CLIENT_REQUEST_DELETE_PROFILE,
    AuthorizedNetCommand:new(EHandlers.OnClientRequestDeleteProfile))

local function registerNetListeners(registry)
    local function handleNetMessage(channel, payload, peerId)
        registry:execute(channel, payload, peerId)
    end

    for channel, _ in pairs(registry.commands) do
        Ext.RegisterNetListener(channel, handleNetMessage)
    end
end

local function registerModEventListeners(registry)
    for eventName, handler in pairs(registry) do
        ModEventManager:Subscribe(eventName, handler)
    end
end

-- Subscribe to events
function SubscribedEvents.SubscribeToEvents()
    -- When resetting Lua states
    -- Ext.Events.ResetCompleted:Subscribe(EHandlers.OnReset)

    -- When the game is started, load the MCM settings
    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "before", EHandlers.OnLevelGameplayStarted)

    Ext.Osiris.RegisterListener("UserConnected", 3, "after", function(userID, userName, userProfileID)
        MCMDebug(1, "UserConnected: " .. userID .. " " .. userName .. " " .. userProfileID)
        MCMWarn(1, "TODO: creating MCM window for new user")
    end)

    Ext.Events.SessionLoaded:Subscribe(EHandlers.OnSessionLoaded)

    registerNetListeners(netEventsRegistry)
    registerModEventListeners(modEventRegistry)
end

return SubscribedEvents
