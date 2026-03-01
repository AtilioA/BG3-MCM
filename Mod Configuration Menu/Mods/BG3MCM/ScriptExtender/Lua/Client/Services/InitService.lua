--- Client initialization service responsible for one-time setup and config loading

local LoadOrderHealthCheckToggles = require("Shared/Helpers/LoadOrderHealthCheck/LoadOrderHealthCheckToggles")

local _initialized = false

local function applyOpenOnStartFirstRunMigration()
    if not MCM.Store then
        MCMWarn(0, "Store API unavailable; skipping open_on_start first-run migration")
        return
    end

    MCM.Store.RegisterVar("open_on_start_first_run_handled", {
        type = "boolean",
        default = false,
        storage = "json"
    })

    if MCM.Get({ settingId = "open_on_start" }) == false then
        MCMDebug(1, "open_on_start is already false, marking first-run migration as handled")
        MCM.Store.Set({ var = "open_on_start_first_run_handled", value = true })
        return
    end

    if MCM.Store.Get("open_on_start_first_run_handled") == true then
        return
    end

    if not MCMClientState or not MCMClientState.UIReady then
        MCMWarn(0, "UIReady unavailable; skipping open_on_start first-run migration")
        return
    end

    local subscription
    subscription = MCMClientState.UIReady:Subscribe(function(isReady)
        if not isReady then
            return
        end

        local success = MCM.Set({ settingId = "open_on_start", value = false, shouldEmitEvent = true })
        if not success then
            MCMWarn(0, "Failed to disable open_on_start during first-run migration")
            return
        end

        MCM.Store.Set({ var = "open_on_start_first_run_handled", value = true })
        if subscription and not subscription._unsubscribed then
            subscription:Unsubscribe()
        end
    end)
end

--- Initialize Client MCM once
function InitClientMCM()
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
    elseif _initialized then
        MCMDebug(1, "Client MCM already initialized, not reinitializing.")
        return
    else
        -- In-game: request configs from server, client will update via net listeners
        NetChannels.MCM_CLIENT_REQUEST_CONFIGS:RequestToServer(
            { message = "Client reset has completed. Requesting MCM settings from server." },
            function(response)
                if response.success then
                    MCMDebug(1, "Successfully requested configs from server after reset")
                else
                    MCMWarn(0,
                        "Failed to request configs from server after reset: " ..
                        (response.error or "Unknown error"))
                end
            end
        )
    end

    applyOpenOnStartFirstRunMigration()

    _initialized = true
end
