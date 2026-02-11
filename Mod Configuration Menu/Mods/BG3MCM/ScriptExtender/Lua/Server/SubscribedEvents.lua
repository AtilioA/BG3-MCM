SubscribedEvents = {}

local netEventsRegistry = CommandRegistry:new()
local modEventRegistry = CommandRegistry:new()

--- Net message handler for when the (IMGUI) client requests the MCM settings to be loaded
netEventsRegistry:register("MCM_Client_Request_Configs", NetCommand:new(EHandlers.OnClientRequestConfigs))

--- Net message handler to relay messages to other clients (backwards support for deprecated net message usage)
netEventsRegistry:register("MCM_Relay_To_Clients", NetCommand:new(EHandlers.OnRelayToClients))
netEventsRegistry:register("MCM_Emit_On_Server", NetCommand:new(EHandlers.OnEmitOnServer))
netEventsRegistry:register("MCM_Ensure_ModVar_Registered", NetCommand:new(EHandlers.OnEnsureModVarRegistered))

--- Net message handlers for when the (IMGUI) client opens or closes the MCM window
modEventRegistry:register(EventChannels.MCM_WINDOW_OPENED, EHandlers.OnUserOpenedWindow)
modEventRegistry:register(EventChannels.MCM_WINDOW_CLOSED, EHandlers.OnUserClosedWindow)

--- Net message handler for when the user spams the MCM button (the window is probably not open)
netEventsRegistry:register("MCM_Client_Show_Troubleshooting_Notification",
    NetCommand:new(EHandlers.OnUserSpamMCMButton))

--- Authorized NetCommand interface (inherits from NetCommand, check if user can edit settings etc)
--- Net message handler for when the (IMGUI) client requests a setting to be set
netEventsRegistry:register("MCM_Client_Request_Set_Setting_Value",
    AuthorizedNetCommand:new(EHandlers.OnClientRequestSetSettingValue))
netEventsRegistry:register("MCM_Client_Request_Reset_Setting_Value",
    AuthorizedNetCommand:new(EHandlers.OnClientRequestResetSettingValue))

--- Net message handler for when the (IMGUI) client requests profiles data
-- registry:register("MCM_Client_Request_Profiles", AuthorizedCommand:new(EHandlers.OnClientRequestProfiles))

--- Net message handler for when the (IMGUI) client requests a profile to be set
netEventsRegistry:register("MCM_Client_Request_Set_Profile",
    AuthorizedNetCommand:new(EHandlers.OnClientRequestSetProfile))

--- Net message handler for when the (IMGUI) client requests a profile to be created
netEventsRegistry:register("MCM_Client_Request_Create_Profile",
    AuthorizedNetCommand:new(EHandlers.OnClientRequestCreateProfile))

--- Net message handler for when the (IMGUI) client requests a profile to be deleted
netEventsRegistry:register("MCM_Client_Request_Delete_Profile",
    AuthorizedNetCommand:new(EHandlers.OnClientRequestDeleteProfile))

-- Wire up NetChannel request handlers using the registry
-- This replaces the old Ext.RegisterNetListener pattern
local function wireRequestHandlers()
    -- Map request/reply channel objects to their registry keys
    -- These channels expect a response from the server
    local requestReplyChannels = {
        [NetChannels.MCM_CLIENT_REQUEST_CONFIGS] = "MCM_Client_Request_Configs",
        [NetChannels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE] = "MCM_Client_Request_Set_Setting_Value",
        [NetChannels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE] = "MCM_Client_Request_Reset_Setting_Value",
        [NetChannels.MCM_CLIENT_REQUEST_SET_PROFILE] = "MCM_Client_Request_Set_Profile",
        [NetChannels.MCM_CLIENT_REQUEST_CREATE_PROFILE] = "MCM_Client_Request_Create_Profile",
        [NetChannels.MCM_CLIENT_REQUEST_DELETE_PROFILE] = "MCM_Client_Request_Delete_Profile",
    }

    -- Map fire-and-forget channel objects to their registry keys
    -- These channels do not expect a response (cross-context event emission)
    local fireAndForgetChannels = {
        [NetChannels.MCM_RELAY_TO_CLIENTS] = "MCM_Relay_To_Clients",
        [NetChannels.MCM_EMIT_ON_SERVER] = "MCM_Emit_On_Server",
        [NetChannels.MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION] = "MCM_Client_Show_Troubleshooting_Notification",
        [NetChannels.MCM_ENSURE_MODVAR_REGISTERED] = "MCM_Ensure_ModVar_Registered",
    }

    -- Wire up request/reply handlers
    for channel, registryKey in pairs(requestReplyChannels) do
        local command = netEventsRegistry.commands[registryKey]
        if command then
            channel:SetRequestHandler(function(data, peerId)
                -- Auto-wrap in xpcall for error handling
                local ok, result = xpcall(function()
                    return command:execute(data, peerId)
                end, function(err)
                    MCMError(0, "NetChannel handler error for " .. registryKey .. ": " .. tostring(err))
                    return { success = false, error = tostring(err) }
                end)

                if not ok then
                    return { success = false, error = tostring(result) }
                end

                -- Ensure response has standard structure
                if type(result) == "table" and result.success ~= nil then
                    return result
                else
                    return { success = true, data = result }
                end
            end)
        end
    end

    -- Wire up fire-and-forget handlers
    for channel, registryKey in pairs(fireAndForgetChannels) do
        local command = netEventsRegistry.commands[registryKey]
        if command then
            channel:SetHandler(function(data, peerId)
                -- Auto-wrap in xpcall for error handling
                xpcall(function()
                    command:execute(data, peerId)
                end, function(err)
                    MCMError(0, "NetChannel handler error for " .. registryKey .. ": " .. tostring(err))
                end)
            end)
        end
    end
end

local function registerLegacyRelayListeners()
    local relayCommand = netEventsRegistry.commands["MCM_Relay_To_Clients"]
    if not relayCommand then
        return
    end

    Ext.RegisterNetListener(NetChannels._LEGACY.MCM_RELAY_TO_CLIENTS, function(_, metapayload, peerId)
        local ok, data = pcall(Ext.Json.Parse, metapayload)
        if not ok or type(data) ~= "table" then
            MCMWarn(0, "Invalid legacy relay payload received on server")
            return
        end

        relayCommand:execute(data, peerId)
    end)
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
    Ext.Osiris.RegisterListener("SavegameLoaded", 0, "before", EHandlers.SavegameLoaded)
    Ext.Osiris.RegisterListener("CharacterCreationStarted", 0, "after", EHandlers.CCStarted)

    Ext.Osiris.RegisterListener("UserConnected", 3, "after", function(userID, userName, userProfileID)
        MCMDebug(1, "UserConnected: " .. userID .. " " .. userName .. " " .. userProfileID)
        MCMServer:LoadAndSendSettingsToUser(userID)
    end)

    Ext.Events.SessionLoaded:Subscribe(EHandlers.OnSessionLoaded)

    MCMAPI.ConfigsLoaded:Subscribe(function(ConfigsLoaded)
        if not ConfigsLoaded then
            return
        end
        MCMPrinter:UpdateLogLevels()
    end)

    wireRequestHandlers()
    registerLegacyRelayListeners()
    registerModEventListeners(modEventRegistry)
end

return SubscribedEvents
