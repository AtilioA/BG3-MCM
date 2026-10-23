D.describe("setting write outcome", { tags = { "settings", "client", "unit" } }, function()

    D.test("reports local saved and rejected outcomes", function(ctx)
        local shouldAccept = true
        local reconciled = {}
        ctx.stub(MCMProxy, "IsMainMenu", function() return true end)
        ctx.stub(MCMAPI, "SetSettingValue", function(_, settingId, value, modUUID, shouldEmitEvent)
            D.expect(settingId).toBe("local-setting")
            D.expect(value).toBe(42)
            D.expect(modUUID).toBe("test-mod")
            D.expect(shouldEmitEvent).toBe(true)
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
        D.expect(rejected).toEqual({ accepted = false, state = "rejected", error = "Setting value was rejected" })
        D.expect(reconciled).toEqual({ 42 })
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

    -- Coverage gap: forwarding does not detect duplicate UI reconciliation after repeated writes.
    -- Keybindings.test.lua separately guards load-subscription churn.
    D.test("forwards the write to the proxy", function(ctx)
        local receipt = { accepted = true, state = "queued", value = 7 }
        local forwarded = nil
        local uiCallback = function() end
        ctx.stub(MCMProxy, "SetSettingValue", function(_, settingId, value, modUUID, setUIValue, shouldEmitEvent)
            forwarded = {
                settingId = settingId,
                value = value,
                modUUID = modUUID,
                setUIValue = setUIValue,
                shouldEmitEvent = shouldEmitEvent,
            }
            return receipt
        end)

        local result = IMGUIAPI:SetSettingValue("setting", 7, "test-mod", uiCallback, true)

        D.expect(result).toBe(receipt)
        D.expect(forwarded.settingId).toBe("setting")
        D.expect(forwarded.value).toBe(7)
        D.expect(forwarded.modUUID).toBe("test-mod")
        D.expect(forwarded.setUIValue).toBe(uiCallback)
        D.expect(forwarded.shouldEmitEvent).toBe(true)
    end)
end)
