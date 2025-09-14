RequireFiles("Client/", {
    "Helpers/_Init",
    "Services/_Init",
    "MCMProxy",
    "Components/_Init",
    "MCMRendering",
    "IMGUIAPI",
    "SubscribedEvents",
})

local LoadOrderHealthCheckToggles = require("Shared/Helpers/LoadOrderHealthCheck/LoadOrderHealthCheckToggles")

local function initClientMCM()
    if MCMProxy.IsMainMenu() then
        LoadOrderHealthCheckToggles:RunAllChecks(e)
        MCMAPI:LoadConfigs()
        MCMClientState:LoadMods(MCMAPI.mods)
    else
        Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_CONFIGS, Ext.Json.Stringify({
            message = "Client reset has completed. Requesting MCM settings from server."
        }))
    end
end

-- initClientMCM()
