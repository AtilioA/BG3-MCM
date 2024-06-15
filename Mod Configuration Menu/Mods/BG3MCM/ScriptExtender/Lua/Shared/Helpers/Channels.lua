Channels = {}

-- Define channel constants for communication between the client and server
Channels.MCM_RELAY_TO_SERVERS = "MCM_Relay_To_Servers"

Channels.MCM_SAVED_SETTING = "MCM_Saved_Setting"
Channels.MCM_SETTING_UPDATED = "MCM_Setting_Updated"
Channels.MCM_SETTING_RESET = "MCM_Setting_Reset"
Channels.MCM_RESET_ALL_MOD_SETTINGS = "MCM_Reset_All_Mod_Settings"
Channels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT = "MCM_Server_Send_Configs_To_Client"

Channels.MCM_SERVER_CREATED_PROFILE = "MCM_Server_Created_Profile"
Channels.MCM_SERVER_SET_PROFILE = "MCM_Server_Set_Profile"
Channels.MCM_SERVER_DELETED_PROFILE = "MCM_Server_Deleted_Profile"

Channels.MCM_MOD_TAB_ADDED = "MCM_Mod_Tab_Added"

Channels.MCM_CLIENT_REQUEST_CONFIGS = "MCM_Client_Request_Configs"
Channels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE = "MCM_Client_Request_Set_Setting_Value"
Channels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE = "MCM_Client_Request_Reset_Setting_Value"

Channels.MCM_CLIENT_REQUEST_PROFILES = "MCM_Client_Request_Profiles"
Channels.MCM_CLIENT_REQUEST_SET_PROFILE = "MCM_Client_Request_Set_Profile"
Channels.MCM_CLIENT_REQUEST_CREATE_PROFILE = "MCM_Client_Request_Create_Profile"
Channels.MCM_CLIENT_REQUEST_DELETE_PROFILE = "MCM_Client_Request_Delete_Profile"

Channels.MCM_WINDOW_READY = "MCM_Window_Ready"

Channels.MCM_USER_OPENED_WINDOW = "MCM_User_Opened_Window"
Channels.MCM_USER_CLOSED_WINDOW = "MCM_User_Closed_Window"

Channels.MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION = "MCM_Client_Show_Troubleshooting_Notification"

return Channels
