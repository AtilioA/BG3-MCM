-- Client-side manager for dynamic settings

---@class DynamicSettingsManager
local DynamicSettingsManager = {
    -- Store for server-side variables received from the server
    serverSideVars = {},
    -- Track all created widgets for refresh functionality
    allWidgetDescriptors = {},
    -- Global settings
    tryWriteToClient = true,
    tryWriteToServer = false
}

-- Channel names for network communication
local NET_CHANNEL_SERVER_VARS = "MCM_ServerVars"
local NET_CHANNEL_SET_SETTING = "MCM_SetSetting"
local NET_CHANNEL_SET_SETTING_RESULT = "MCM_SetSettingResult"

-- Discover client-side variables
function DynamicSettingsManager.DiscoverClientVars()
    local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService")
    local clientVars = {}
    
    -- Discover all mod variables on the client
    local mods = Ext.Mod.GetLoadOrder()
    for _, mod in ipairs(mods) do
        local moduleUUID = mod.UUID -- UUID is injected by the Script Extender
        local modVars = Ext.Vars.GetModVariables(moduleUUID)
        
        if modVars then
            clientVars[moduleUUID] = {}
            
            -- Register each variable with SettingsService and add to our collection
            for varName, varValue in pairs(modVars) do
                SettingsService.RegisterDiscoveredVariable(moduleUUID, varName, "ModVar")
                clientVars[moduleUUID][varName] = {
                    value = varValue,
                    type = type(varValue)
                }
            end
        end
    end
    
    return clientVars
end

-- Handle incoming server variables
function DynamicSettingsManager.HandleServerVars(channel, payload)
    if channel ~= NET_CHANNEL_SERVER_VARS then return end
    
    local data = Ext.Json.Parse(payload)
    DynamicSettingsManager.serverSideVars = data
    MCMDebug(1, "Received server variables")
    
    -- Trigger UI refresh if needed
    ModEventManager:Emit(EventChannels.MCM_SERVER_VARS_UPDATED, {}, true)
end

-- Handle setting result from server
function DynamicSettingsManager.HandleSetSettingResult(channel, payload)
    if channel ~= NET_CHANNEL_SET_SETTING_RESULT then return end
    
    local data = Ext.Json.Parse(payload)
    local Notifications = Ext.Require("Client/UI/Notifications") -- Assuming this is where ShowInfo is defined
    if data.Success then
        Notifications.ShowInfo("Setting updated successfully: " .. data.Key)
    else
        Notifications.ShowInfo("Error updating setting: " .. (data.Error or "Unknown error"), {r=1, g=0, b=0, a=1})
    end
end

-- Try to set a variable on the client
function DynamicSettingsManager.TrySetOnClient(moduleUUID, key, store, value)
    if not DynamicSettingsManager.tryWriteToClient then
        return false, "Client write disabled"
    end
    
    local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService")
    local success, error = pcall(function()
        SettingsService.Set(moduleUUID, key, store, value)
    end)
    
    return success, error
end

-- Try to set a variable on the server
function DynamicSettingsManager.TrySetOnServer(moduleUUID, key, store, value)
    if not DynamicSettingsManager.tryWriteToServer then
        return false, "Server write disabled"
    end
    
    if MCMProxy.IsMainMenu() then
        return false, "Cannot write to server in main menu"
    end
    
    -- Send request to server
    local data = {
        Module = moduleUUID,
        Key = key,
        Store = store,
        Value = value
    }
    
    Ext.ClientNet.PostMessageToServer(NET_CHANNEL_SET_SETTING, Ext.Json.Stringify(data))
    return true
end

-- Set a variable (tries both client and server based on settings)
function DynamicSettingsManager.SetVariable(moduleUUID, key, store, value)
    local clientResult, clientError = DynamicSettingsManager.TrySetOnClient(moduleUUID, key, store, value)
    local serverResult = DynamicSettingsManager.TrySetOnServer(moduleUUID, key, store, value)
    
    return clientResult or serverResult, clientError
end

-- Refresh all dynamic settings
function DynamicSettingsManager.RefreshAll()
    -- Destroy all existing widgets
    for _, widget in pairs(DynamicSettingsManager.allWidgetDescriptors) do
        if widget.Destroy then
            widget:Destroy()
        end
    end
    
    -- Clear the widget collection
    DynamicSettingsManager.allWidgetDescriptors = {}
    
    -- Re-discover client variables
    DynamicSettingsManager.DiscoverClientVars()
    
    -- Re-discover server variables if in-game
    if not MCMProxy.IsMainMenu() then
        -- Request server to re-broadcast variables
        Ext.ClientNet.PostMessageToServer("MCM_RequestServerVars", "{}")
    end
    
    -- Trigger UI rebuild
    ModEventManager:Emit(EventChannels.MCM_DYNAMIC_SETTINGS_REFRESHED, {}, true)
end

-- Initialize the dynamic settings manager
function DynamicSettingsManager.Initialize()
    -- Register network listeners
    Ext.Events.NetMessage:Subscribe(DynamicSettingsManager.HandleServerVars)
    Ext.Events.NetMessage:Subscribe(DynamicSettingsManager.HandleSetSettingResult)
    
    -- Add server vars request handler on the server
    if Ext.IsServer() then
        Ext.Net.RegisterNetListener("MCM_RequestServerVars", function() -- RegisterNetListener is injected by the Script Extender
            local ServerDiscovery = Ext.Require("Server/DynamicSettings/ServerDiscovery")
            ServerDiscovery.DiscoverAndBroadcast()
        end)
    end
    
    -- Discover client variables on initialization
    DynamicSettingsManager.DiscoverClientVars()
    
    MCMDebug(1, "DynamicSettingsManager initialized")
end

return DynamicSettingsManager
