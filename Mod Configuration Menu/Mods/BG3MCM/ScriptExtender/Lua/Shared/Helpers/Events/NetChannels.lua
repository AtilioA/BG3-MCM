-- Net channels for communication between the client and server; these are only used for internal communication between the MCM clients and server, and not for listening to actual MCM events.
-- 1.40: Modernized to actually use NetChannel API (Ext.Net.CreateChannel)

NetChannels = {}

-- Helper to create NetChannel objects
local function createChannel(name)
    return Ext.Net.CreateChannel(ModuleUUID, name)
end

-- Cross-context relay channels (broadcast)
NetChannels.MCM_RELAY_TO_SERVERS = createChannel("MCM_Relay_To_Servers")
NetChannels.MCM_RELAY_TO_CLIENTS = createChannel("MCM_Relay_To_Clients")
NetChannels.MCM_EMIT_ON_SERVER = createChannel("MCM_Emit_On_Server")
NetChannels.MCM_EMIT_ON_CLIENTS = createChannel("MCM_Emit_On_Clients")

-- Server -> Client config push (broadcast)
NetChannels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT = createChannel("MCM_Server_Send_Configs_To_Client")

-- Chunked transfer channels (INIT -> CHUNK -> END)
NetChannels.MCM_CHUNK_INIT = createChannel("MCM_Chunk_Init")
NetChannels.MCM_CHUNK_PART = createChannel("MCM_Chunk_Part")
NetChannels.MCM_CHUNK_END = createChannel("MCM_Chunk_End")

-- Client request channels (use Request/Reply pattern)
NetChannels.MCM_CLIENT_REQUEST_CONFIGS = createChannel("MCM_Client_Request_Configs")
NetChannels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE = createChannel("MCM_Client_Request_Set_Setting_Value")
NetChannels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE = createChannel("MCM_Client_Request_Reset_Setting_Value")
NetChannels.MCM_ENSURE_MODVAR_REGISTERED = createChannel("MCM_Ensure_ModVar_Registered")

-- Profile management channels (use Request/Reply pattern)
NetChannels.MCM_CLIENT_REQUEST_PROFILES = createChannel("MCM_Client_Request_Profiles")
NetChannels.MCM_CLIENT_REQUEST_SET_PROFILE = createChannel("MCM_Client_Request_Set_Profile")
NetChannels.MCM_CLIENT_REQUEST_CREATE_PROFILE = createChannel("MCM_Client_Request_Create_Profile")
NetChannels.MCM_CLIENT_REQUEST_DELETE_PROFILE = createChannel("MCM_Client_Request_Delete_Profile")

-- Notification channel
NetChannels.MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION = createChannel("MCM_Client_Show_Troubleshooting_Notification")

-- Legacy string constants for backwards compatibility (deprecated NetMessage usage)
-- These are kept for postNetMessageToServerAndClients which maintains backwards compatibility
NetChannels._LEGACY = {
    MCM_RELAY_TO_SERVERS = "MCM_Relay_To_Servers",
    MCM_RELAY_TO_CLIENTS = "MCM_Relay_To_Clients",
    MCM_EMIT_ON_SERVER = "MCM_Emit_On_Server",
    MCM_EMIT_ON_CLIENTS = "MCM_Emit_On_Clients",
    MCM_SERVER_SEND_CONFIGS_TO_CLIENT = "MCM_Server_Send_Configs_To_Client",
    MCM_CHUNK_INIT = "MCM_Chunk_Init",
    MCM_CHUNK_PART = "MCM_Chunk_Part",
    MCM_CHUNK_END = "MCM_Chunk_End",
}

return NetChannels
