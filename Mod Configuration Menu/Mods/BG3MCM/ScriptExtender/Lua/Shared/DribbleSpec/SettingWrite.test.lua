D.describe("setting write outcome", { tags = { "settings", "client", "unit" } }, function()

    D.test("reports local saved and rejected outcomes", function(ctx)
        local shouldAccept = true
        local reconciled = {}
        ctx.stub(MCMProxy, "IsMainMenu", function() return true end)
        ctx.stub(MCMAPI, "SetSettingValue", function(_, settingId, value, modUUID, shouldEmitEvent)
            D.expect(settingId).toBe("local-setting")
            D.expect(value).toBe(42)
            D.expect(modUUID).toBe("test-mod")
            D.expect(shouldEmitEvent).toBeTruthy()
            return shouldAccept
        end)

        local saved = MCMProxy:SetSettingValue("local-setting", 42, "test-mod", function(value)
            table.insert(reconciled, value)
        end, true)
        D.expect(saved).toEqual({ accepted = true, state = "saved", value = 42 })
        D.expect(reconciled).toEqual({ 42 })

        shouldAccept = false
        local rejected = MCMProxy:SetSettingValue("local-setting", 42, "test-mod", function(value)
            table.insert(reconciled, value)
        end, true)
        D.expect(rejected.accepted).toBeFalsy()
        D.expect(rejected.state).toBe("rejected")
        D.expect(#reconciled).toBe(1)
    end)

    D.test("queues remote writes without touching the UI", function(ctx)
        local reply = nil
        local reconciled = {}
        local emitted = {}
        ctx.stub(MCMProxy, "IsMainMenu", function() return false end)
        ctx.stub(NetChannels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE, "RequestToServer",
            function(_, payload, callback)
                D.expect(payload.settingId).toBe("remote-setting")
                D.expect(payload.value).toBe("second")
                reply = callback
            end)
        ctx.stub(ModEventManager, "Emit", function(_, eventName, payload, bothContexts)
            table.insert(emitted, { eventName = eventName, payload = payload, bothContexts = bothContexts })
        end)

        local receipt = MCMProxy:SetSettingValue("remote-setting", "second", "test-mod", function(value)
            table.insert(reconciled, value)
        end, true)
        D.expect(receipt).toEqual({ accepted = true, state = "queued", value = "second" })

        -- The response only logs. Rollback arrives through the authoritative broadcast.
        reply({ success = false, error = "rejected" })
        D.expect(#reconciled).toBe(0)
        D.expect(#emitted).toBe(0)
    end)

    D.test("does not create UI event subscriptions per write", function(ctx)
        local subscriptions = 0
        local receipt = { accepted = true, state = "queued", value = 7 }
        ctx.stub(MCMProxy, "SetSettingValue", function() return receipt end)
        ctx.stub(ModEventManager, "Subscribe", function()
            subscriptions = subscriptions + 1
        end)

        local result = IMGUIAPI:SetSettingValue("setting", 7, "test-mod", function() end, true)

        D.expect(result).toEqual(receipt)
        D.expect(subscriptions).toBe(0)
    end)
end)
