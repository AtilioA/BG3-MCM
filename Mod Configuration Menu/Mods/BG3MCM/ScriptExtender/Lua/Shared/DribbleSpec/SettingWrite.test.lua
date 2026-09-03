D.describe("setting write outcome", { tags = { "settings", "client", "unit" } }, function()
    D.afterEach(function()
        MCMProxy.PendingSettingWrites = {}
    end)

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

    D.test("ignores stale replies and never rolls back from the response", function(ctx)
        local requests = {}
        local reconciled = {}
        local emitted = {}
        ctx.stub(MCMProxy, "IsMainMenu", function() return false end)
        ctx.stub(NetChannels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE, "RequestToServer",
            function(_, payload, callback)
                table.insert(requests, { payload = payload, callback = callback })
            end)
        ctx.stub(ModEventManager, "Emit", function(_, eventName, payload, bothContexts)
            table.insert(emitted, { eventName = eventName, payload = payload, bothContexts = bothContexts })
        end)

        local first = MCMProxy:SetSettingValue("remote-setting", "first", "test-mod", function(value)
            table.insert(reconciled, value)
        end, true)
        local second = MCMProxy:SetSettingValue("remote-setting", "second", "test-mod", function(value)
            table.insert(reconciled, value)
        end, true)

        D.expect(first).toEqual({ accepted = true, state = "queued", value = "first" })
        D.expect(second).toEqual({ accepted = true, state = "queued", value = "second" })
        D.expect(#requests).toBe(2)

        requests[1].callback({ success = false, error = "stale rejection" })
        D.expect(#reconciled).toBe(0)
        D.expect(#emitted).toBe(0)

        -- Rollback is driven by the authoritative broadcast, not the response.
        requests[2].callback({ success = false, error = "rejected" })
        D.expect(#reconciled).toBe(0)
        D.expect(#emitted).toBe(0)
        D.expect(MCMProxy.PendingSettingWrites["test-mod:remote-setting"]).toBeNil()
    end)

    D.test("clears pending state on server reply without echoing", function(ctx)
        local reply = nil
        local reconciled = nil
        ctx.stub(MCMProxy, "IsMainMenu", function() return false end)
        ctx.stub(NetChannels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE, "RequestToServer",
            function(_, _, callback) reply = callback end)

        MCMProxy:SetSettingValue("remote-setting", "submitted", "test-mod", function(value)
            reconciled = value
        end, true)
        reply({ success = true, data = { value = "accepted" } })

        D.expect(reconciled).toBeNil()
        D.expect(MCMProxy.PendingSettingWrites["test-mod:remote-setting"]).toBeNil()
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
