-- Server-side discovery and network handling for dynamic settings

---@class ServerDiscovery
local ServerDiscovery = {}

-- Channel names for network communication
local NET_CHANNEL_SERVER_VARS = "MCM_ServerVars"
local NET_CHANNEL_SET_SETTING = "MCM_SetSetting"
local NET_CHANNEL_SET_SETTING_RESULT = "MCM_SetSettingResult"

local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local StorageManager = Ext.Require("Shared/DynamicSettings/Services/StorageManager.lua")

-- Discover and broadcast all server-side variables to clients
function ServerDiscovery.DiscoverAndBroadcast()
    local allServerVars = {}

    -- Use StorageManager to discover all variables
    StorageManager.DiscoverAllVariables()

    -- TODO: replace with proper SettingsService method
    allServerVars = SettingsService.schema

    -- Broadcast to all clients
    Ext.ServerNet.BroadcastMessage(NET_CHANNEL_SERVER_VARS, Ext.Json.Stringify(allServerVars))
    MCMDebug(1, "Broadcasted server variables to clients")

    return allServerVars
end

-- Handle client requests to set server-side settings
function ServerDiscovery.HandleSetSettingRequest(channel, payload, userId)
    if channel ~= NET_CHANNEL_SET_SETTING then return end

    local data = Ext.Json.Parse(payload)

    local moduleUUID = data.Module
    local key = data.Key
    local store = data.Store
    local value = data.Value

    local result = {
        Module = moduleUUID,
        Key = key,
        Store = store,
        Success = false,
        Error = nil
    }

    -- Attempt to set the value and capture any errors
    local success, error = pcall(function()
        SettingsService.Set(moduleUUID, key, store, value)
    end)

    result.Success = success
    if not success then
        result.Error = tostring(error)
        MCMWarn(1, "Error setting " .. moduleUUID .. ":" .. key .. ": " .. tostring(error))
    else
        MCMDebug(1, "Successfully set " .. moduleUUID .. ":" .. key .. " to " .. tostring(value))
    end

    -- Send result back to the client who made the request
    Ext.ServerNet.PostMessageToUser(userId, NET_CHANNEL_SET_SETTING_RESULT, Ext.Json.Stringify(result))
end

-- Initialize server discovery
function ServerDiscovery.Initialize()
    -- Initialize the StorageManager
    StorageManager.Initialize()

    -- Subscribe to session loaded event to discover and broadcast variables
    Ext.Events.SessionLoaded:Subscribe(function()
        -- Broadcast server variables to clients
        ServerDiscovery.DiscoverAndBroadcast()
    end)

    -- Subscribe to client requests to set settings
    -- RegisterNetListener is injected by the Script Extender
    ---@diagnostic disable-next-line: undefined-field
    Ext.RegisterNetListener(NET_CHANNEL_SET_SETTING, ServerDiscovery.HandleSetSettingRequest)

    MCMDebug(1, "ServerDiscovery initialized")
end

return ServerDiscovery
