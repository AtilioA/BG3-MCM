D.describe("MCM initialization isolation", { tags = { "initialization", "client", "unit" } }, function()
    local initializedBefore
    D.beforeEach(function()
        initializedBefore = InputCallbackManager._initialized
    end)
    D.afterEach(function()
        InputCallbackManager._initialized = initializedBefore
    end)

    D.test("creates mod pages and signals readiness after a hotkeys page failure", function(ctx)
        ctx.requireClient()
        local calls = {}
        ctx.stub(MCMRendering, "CreateProfileManagementHeader", function(_self)
            table.insert(calls, "profile")
        end)
        ctx.stub(MCMRendering, "CreateKeybindingsPage", function(_self)
            table.insert(calls, "hotkeys")
            error("Hotkeys fixture failed")
        end)
        ctx.stub(MCMRendering, "CreateMainTable", function(_self)
            table.insert(calls, "pages")
        end)
        ctx.stub(MCMClientState.UIReady, "OnNext", function(_subject, ready)
            D.expect(ready).toBe(true)
            table.insert(calls, "ready")
        end)
        ctx.stub(MCMPrinter, "PrintError", function(_self, _level, _format, message)
            D.expect(message:find("Hotkeys fixture failed", 1, true) ~= nil).toBe(true)
            table.insert(calls, "error")
        end)

        MCMRendering:CreateModMenu()

        D.expect(calls).toEqual({ "profile", "hotkeys", "error", "pages", "ready" })
    end)

    D.test("continues later enabled health checks after one fails", function(ctx)
        ctx.requireClient()
        local calls = {}
        ctx.stub(MCMUtils, "IsClientMainMenu", function() return true end)
        ctx.stub(MCMAPI, "GetSettingValue", function(_self, settingId, _modUUID)
            return settingId == "enable_loadorder_dependencies_check" or settingId == "enable_modconflicts_check"
        end)
        ctx.stub(LoadOrderHealthCheck, "WarnAboutLoadOrderDependencies", function(_self)
            table.insert(calls, "dependencies")
            error("Dependencies fixture failed")
        end)
        ctx.stub(LoadOrderHealthCheck, "WarnAboutModConflicts", function(_self)
            table.insert(calls, "conflicts")
        end)
        ctx.stub(MCMPrinter, "PrintError", function(_self, _level, _format, settingId, message)
            D.expect(settingId).toBe("enable_loadorder_dependencies_check")
            D.expect(message:find("Dependencies fixture failed", 1, true) ~= nil).toBe(true)
            table.insert(calls, "error")
        end)

        LoadOrderHealthCheckToggles:RunAllChecks()

        D.expect(calls).toEqual({ "dependencies", "error", "conflicts" })
    end)

    D.test("initializes hotkey dispatch despite an optional view failure", function(ctx)
        ctx.requireClient()
        InputCallbackManager._initialized = false
        local observed = {}
        ctx.stub(MCMRendering, "CreateProfileManagementHeader", function(_self) end)
        ctx.stub(MCMRendering, "GetAllKeybindings", function(_self) return {} end)
        ctx.stub(KeybindingsRegistry, "RegisterModKeybindings", function(_bindings)
            observed.registry = true
        end)
        ctx.stub(InputCallbackManager, "Initialize", function()
            observed.dispatcher = true
        end)
        ctx.stub(ModEventManager, "Emit", function(_self, eventName, _payload)
            D.expect(eventName).toBe(EventChannels.MCM_KEYBINDINGS_LOADED)
            observed.event = true
        end)
        ctx.stub(InputCallbackManager.KeybindingsLoadedSubject, "OnNext", function(_subject, ready)
            observed.loaded = ready
        end)
        ctx.stub(MCMProxy, "RegisterMCMKeybindings", function(_self)
            observed.callbacks = true
        end)
        ctx.stub(KeybindingsUI, "CreateKeybindingsPage", function(_dualPane)
            observed.view = true
            error("Hotkeys view fixture failed")
        end)
        ctx.stub(MCMPrinter, "PrintError", function(_self, _level, _format, message)
            D.expect(message:find("Hotkeys view fixture failed", 1, true) ~= nil).toBe(true)
            observed.error = true
        end)
        ctx.stub(MCMRendering, "CreateMainTable", function(_self)
            observed.pages = true
        end)
        ctx.stub(MCMClientState.UIReady, "OnNext", function(_subject, ready)
            observed.ready = ready
        end)

        MCMRendering:CreateModMenu()

        D.expect(observed).toEqual({
            registry = true, dispatcher = true, event = true, loaded = true,
            callbacks = true, view = true, error = true, pages = true, ready = true,
        })
    end)
end)
