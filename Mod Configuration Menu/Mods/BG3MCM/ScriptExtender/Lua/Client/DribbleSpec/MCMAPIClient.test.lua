local TableInjector = Ext.Require("Shared/Helpers/MCM/GlobalTable/TableInjector.lua")

D.describe("MCMAPI public facade", { tags = { "mcmapi", "unit" } }, function()
    local originalMCMAPIMods
    local originalModConfigMods
    local originalClientMods
    local subscriptionIndex

    D.beforeEach(function()
        originalMCMAPIMods = MCMAPI.mods
        originalModConfigMods = ModConfig.mods
        originalClientMods = MCMClientState.mods
    end)

    D.afterEach(function()
        MCMAPI.mods = originalMCMAPIMods
        ModConfig.mods = originalModConfigMods
        MCMClientState.mods = originalClientMods

        if subscriptionIndex then
            local index = subscriptionIndex
            subscriptionIndex = nil
            ModEventManager:Unsubscribe(EventChannels.MCM_SETTING_SAVED, index)
        end
    end)

    D.test("TestPublicFacadeSetReadsBackAndDeliversSavedEvent", function(ctx)
        local modUUID = TestConstants.ModuleUUIDs[1]
        local settingId = "public-facade-checkbox"
        local blueprint = Blueprint:New({
            ModUUID = modUUID,
            SchemaVersion = 1,
            Settings = {
                BlueprintSetting:New({
                    Id = settingId,
                    Name = "Public facade checkbox",
                    Type = "checkbox",
                    Default = true,
                }),
            },
        })
        local mod = {
            blueprint = blueprint,
            settingsValues = { [settingId] = true },
        }
        local receivedEvents = {}

        MCMAPI.mods = { [modUUID] = mod }
        ModConfig.mods = { [modUUID] = mod }
        MCMClientState.mods = {}
        ctx.stub(MCMProxy, "IsMainMenu", function() return true end)
        ctx.stub(ModConfig, "SaveSettingsForMod", function() end)
        subscriptionIndex = ModEventManager:Subscribe(EventChannels.MCM_SETTING_SAVED, function(eventData)
            table.insert(receivedEvents, eventData)
        end)
        local publicMCM = TableInjector.injectSharedMCMTable({}, modUUID)

        local initialValue = publicMCM.Get(settingId)
        local setResult = publicMCM.Set({
            settingId = settingId,
            value = false,
            shouldEmitEvent = true,
        })
        local readbackValue = publicMCM.Get(settingId)

        D.expect(initialValue).toBe(true)
        D.expect(setResult).toBe(true)
        D.expect(readbackValue).toBe(false)
        -- The payload also carries the legacy modGUID alias, so assert the documented fields only
        D.expect(#receivedEvents).toBe(1)
        local savedEvent = receivedEvents[1]
        D.expect(savedEvent.modUUID).toBe(modUUID)
        D.expect(savedEvent.settingId).toBe(settingId)
        D.expect(savedEvent.value).toBe(false)
        D.expect(savedEvent.oldValue).toBe(true)
    end)
end)

D.describe("List enabled client dispatch", { tags = { "list-enabled-client" } }, function()
    D.test("returns receipt and leaves current value for server authority", function(ctx)
        local uuid = TestConstants.ModuleUUIDs[1]
        local blueprint = Blueprint:New({ ModUUID = uuid, SchemaVersion = 1, Settings = {
            BlueprintSetting:New({ Id = "list", Type = "list_v2", Default = { enabled = true, elements = { { name = "one", enabled = true } } } }),
        } })
        local current = blueprint:RetrieveDefaultValueForSetting("list")
        local original = MCMAPI.mods
        ctx.sandbox:TrackRestore(function() MCMAPI.mods = original end)
        MCMAPI.mods = { [uuid] = { blueprint = blueprint, settingsValues = { list = current } } }
        local sent
        ctx.stub(MCMProxy, "SetSettingValue", function(_, id, value, modUUID, _, emit)
            sent = { id = id, value = value, modUUID = modUUID, emit = emit }
            return { accepted = true }
        end)
        local facade = TableInjector.injectSharedMCMTable({}, uuid)
        D.expect(facade.List.SetEnabled({ listSettingId = "list", itemName = "one", enabled = false, shouldEmitEvent = true })).toBe(true)
        D.expect(sent.id).toBe("list")
        D.expect(sent.modUUID).toBe(uuid)
        D.expect(sent.emit).toBe(true)
        D.expect(sent.value.elements[1].enabled).toBe(false)
        assert(current)
        D.expect(current.elements[1].enabled).toBe(true)
    end)
end)
