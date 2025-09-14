--- Client initialization service responsible for one-time setup and config loading

local LoadOrderHealthCheckToggles = require("Shared/Helpers/LoadOrderHealthCheck/LoadOrderHealthCheckToggles")

local _initialized = false

--- Initialize Client MCM once
function InitClientMCM()
    if _initialized then
        return
    end
    _initialized = true

    if MCMProxy.IsMainMenu() then
        -- Run load order checks when on main menu, then load local configs
        xpcall(function()
            if LoadOrderHealthCheckToggles and LoadOrderHealthCheckToggles.RunAllChecks then
                LoadOrderHealthCheckToggles:RunAllChecks()
            end
        end, function(err)
            MCMWarn(0, "LoadOrderHealthCheckToggles failed: " .. tostring(err))
        end)

        MCMAPI:LoadConfigs()
        MCMClientState:LoadMods(MCMAPI.mods)
        Noesis:MonitorMainMenuButtonPress()
    else
        -- In-game: request configs from server, client will update via net listeners
        Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_CONFIGS, Ext.Json.Stringify({
            message = "Client reset has completed. Requesting MCM settings from server."
        }))
    end
end
