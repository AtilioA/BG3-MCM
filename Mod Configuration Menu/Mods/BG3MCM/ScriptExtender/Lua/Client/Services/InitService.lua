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

    if MCM.Store.Get("open_on_start_first_run_handled") == true then
        return
    end

    local success = MCMAPI:SetSettingValue("open_on_start", false, ModuleUUID, false)
    if not success then
        MCMWarn(0, "Failed to disable open_on_start during first-run migration")
        return
    end

    MCM.Store.Set("open_on_start_first_run_handled", true)
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
        applyOpenOnStartFirstRunMigration()
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

    _initialized = true
end
