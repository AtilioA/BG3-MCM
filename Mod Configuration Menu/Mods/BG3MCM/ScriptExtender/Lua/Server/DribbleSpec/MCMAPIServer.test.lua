local TableInjector = Ext.Require("Shared/Helpers/MCM/GlobalTable/TableInjector.lua")

D.describe("List default lifecycle", { tags = { "list-default-lifecycle" } }, function()
    local uuid, authorDefault, blueprint, mod

    D.beforeEach(function(ctx)
        uuid = ModuleUUID
        authorDefault = { enabled = true, elements = { { name = "original", enabled = true } } }
        blueprint = Blueprint:New({ ModUUID = uuid, SchemaVersion = 1, Settings = {
            BlueprintSetting:New({ Id = "list", Type = "list_v2", Default = authorDefault }),
        } })
        mod = { blueprint = blueprint, settingsValues = {} }
        local oldAPI, oldConfig = MCMAPI.mods, ModConfig.mods
        ctx.sandbox:TrackRestore(function() MCMAPI.mods = oldAPI; ModConfig.mods = oldConfig end)
        MCMAPI.mods, ModConfig.mods = { [uuid] = mod }, { [uuid] = mod }
        ctx.stub(JsonLayer, "SaveJSONFile", function() end)
        ctx.stub(ModConfig, "UpdateAllSettingsForMod", function(self, id, values) self.mods[id].settingsValues = values end)
        ctx.stub(ModEventManager, "Emit", function() end)
    end)

    D.test("fresh settings do not share nested author defaults", function()
        ModConfig:HandleMissingSettings(uuid, blueprint, "mock/settings.json")
        mod.settingsValues.list.elements[1].name = "changed"
        mod.settingsValues.list.elements[1].enabled = false
        D.expect(authorDefault.elements[1].name).toBe("original")
        D.expect(authorDefault.elements[1].enabled).toBe(true)
    end)

    D.test("two resets restore author values after each mutation", function()
        ModConfig:HandleMissingSettings(uuid, blueprint, "mock/settings.json")
        mod.settingsValues.list.elements[1].name = "first change"
        MCMAPI:ResetSettingValue("list", uuid)
        D.expect(mod.settingsValues.list.elements[1].name).toBe("original")
        mod.settingsValues.list.elements[1].name = "second change"
        mod.settingsValues.list.elements[1].enabled = false
        MCMAPI:ResetSettingValue("list", uuid)
        D.expect(mod.settingsValues.list.elements[1].name).toBe("original")
        D.expect(mod.settingsValues.list.elements[1].enabled).toBe(true)
        D.expect(authorDefault.elements[1].name).toBe("original")
        D.expect(authorDefault.elements[1].enabled).toBe(true)
    end)
end)

D.describe("List enabled facade regression", { tags = { "list-enabled-facade" } }, function()
    D.test("rejects invalid requests and preserves old value on accepted writes", function(ctx)
        local uuid = TestConstants.ModuleUUIDs[1]
        local default = { enabled = true, elements = { { name = "one", enabled = true, note = "item" } }, note = "list" }
        local blueprint = Blueprint:New({ ModUUID = uuid, SchemaVersion = 1, Settings = {
            BlueprintSetting:New({ Id = "list", Type = "list_v2", Default = default }),
            BlueprintSetting:New({ Id = "other", Type = "checkbox", Default = true }),
        } })
        local mod = { blueprint = blueprint, settingsValues = { list = blueprint:RetrieveDefaultValueForSetting("list"), other = true } }
        local oldAPI, oldConfig = MCMAPI.mods, ModConfig.mods
        ctx.sandbox:TrackRestore(function() MCMAPI.mods = oldAPI; ModConfig.mods = oldConfig end)
        MCMAPI.mods, ModConfig.mods = { [uuid] = mod }, { [uuid] = mod }
        ctx.stub(ModConfig, "UpdateAllSettingsForMod", function(self, id, values) self.mods[id].settingsValues = values end)
        local events = {}
        ctx.stub(ModEventManager, "Emit", function(_, channel, data)
            if channel == EventChannels.MCM_SETTING_SAVED then table.insert(events, data) end
        end)
        local facade = TableInjector.injectSharedMCMTable({}, uuid)
        local before = table.deepcopy(mod.settingsValues.list)
        for _, args in ipairs({
            { listSettingId = "list", itemName = "one" },
            { listSettingId = "list", itemName = "one", enabled = "false" },
            { listSettingId = "list", itemName = "", enabled = false },
            { listSettingId = "list", itemName = 12, enabled = false },
            { listSettingId = "other", itemName = "one", enabled = false },
        }) do
            D.expect(facade.List.SetEnabled(args)).toBe(false)
            D.expect(mod.settingsValues.list).toEqual(before)
            D.expect(#events).toBe(0)
        end
        D.expect(facade.List.SetEnabled({ listSettingId = "list", itemName = "one", enabled = false, shouldEmitEvent = true })).toBe(true)
        D.expect(mod.settingsValues.list.elements[1].enabled).toBe(false)
        D.expect(mod.settingsValues.list.elements[1].note).toBe("item")
        D.expect(mod.settingsValues.list.note).toBe("list")
        D.expect(#events).toBe(1)
        D.expect(events[1].oldValue).toEqual(before)
        D.expect(blueprint:RetrieveDefaultValueForSetting("list")).toEqual(before)
        D.expect(facade.List.SetEnabled({ listSettingId = "list", itemName = "new", enabled = false, shouldEmitEvent = true })).toBe(true)
        D.expect(mod.settingsValues.list.elements[2].name).toBe("new")
        D.expect(mod.settingsValues.list.elements[2].enabled).toBe(false)
    end)
end)
