-- Net channels for communication between the client and server; these are only used for internal communication between the MCM clients and server, and not for listening to actual MCM events.

NetChannels = {}

NetChannels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT = "MCM_Server_Send_Configs_To_Client"

NetChannels.MCM_CLIENT_REQUEST_CONFIGS = "MCM_Client_Request_Configs"
NetChannels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE = "MCM_Client_Request_Set_Setting_Value"
NetChannels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE = "MCM_Client_Request_Reset_Setting_Value"

NetChannels.MCM_CLIENT_REQUEST_PROFILES = "MCM_Client_Request_Profiles"
NetChannels.MCM_CLIENT_REQUEST_SET_PROFILE = "MCM_Client_Request_Set_Profile"
NetChannels.MCM_CLIENT_REQUEST_CREATE_PROFILE = "MCM_Client_Request_Create_Profile"
NetChannels.MCM_CLIENT_REQUEST_DELETE_PROFILE = "MCM_Client_Request_Delete_Profile"

NetChannels.MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION = "MCM_Client_Show_Troubleshooting_Notification"

return NetChannels