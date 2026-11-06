local TableInjector = Ext.Require("Shared/Helpers/MCM/GlobalTable/TableInjector.lua")

D.describe("MCMAPI", { tags = { "mcmapi", "unit" } }, function()
    local originalMCMAPIMods
    local originalModConfigMods
    local previousClientMods
    local capturedClientMods = false
    local subscriptionIndex

    D.beforeEach(function()
        originalMCMAPIMods = MCMAPI.mods
        originalModConfigMods = ModConfig.mods
    end)

    D.afterEach(function()
        MCMAPI.mods = originalMCMAPIMods
        ModConfig.mods = originalModConfigMods

        if capturedClientMods then
            MCMClientState.mods = previousClientMods
            previousClientMods = nil
            capturedClientMods = false
        end

        if subscriptionIndex then
            local index = subscriptionIndex
            subscriptionIndex = nil
            ModEventManager:Unsubscribe(EventChannels.MCM_SETTING_SAVED, index)
        end
    end)

    local function CreateDynamicEnumBlueprint(defaultValue, currentValue)
        local modUUID = TestConstants.ModuleUUIDs[1]
        local blueprint = Blueprint:New({
            SchemaVersion = 1,
            Settings = {
                BlueprintSetting:New({
                    Id = "dynamic-enum",
                    Name = "Dynamic Enum",
                    Type = "enum",
                    Default = defaultValue,
                    Options = {
                        Choices = {}
                    }
                })
            }
        })

        return modUUID, blueprint, {
            [modUUID] = {
                blueprint = blueprint,
                settingsValues = {
                    ["dynamic-enum"] = currentValue
                }
            }
        }
    end

    D.test("TestSetEnumChoicesShouldFallbackInvalidValueToDefault", function(ctx)
        local modUUID, blueprint, mods = CreateDynamicEnumBlueprint("option-2", "manually-edited-value")

        MCMAPI.mods = mods
        ModConfig.mods = {}
        ctx.stub(ModConfig, "UpdateAllSettingsForMod", function(self, targetModUUID, settings)
            self.mods = self.mods or {}
            self.mods[targetModUUID] = self.mods[targetModUUID] or {}
            self.mods[targetModUUID].settingsValues = settings
        end)
        ctx.stub(ModEventManager, "Emit", function(...) end)

        MCMAPI:SetEnumChoices("dynamic-enum", { "option-1", "option-2" }, nil, modUUID)

        D.expect(blueprint:GetAllSettings()["dynamic-enum"]:GetOptions().Choices).toEqual({ "option-1", "option-2" })
        D.expect(mods[modUUID].settingsValues["dynamic-enum"]).toBe("option-2")
    end)

    D.test("TestSetEnumChoicesShouldFallbackInvalidValueToFirstChoiceWhenDefaultIsUnavailable", function(ctx)
        local modUUID, blueprint, mods = CreateDynamicEnumBlueprint("missing-default", "manually-edited-value")

        MCMAPI.mods = mods
        ModConfig.mods = {}
        ctx.stub(ModConfig, "UpdateAllSettingsForMod", function(self, targetModUUID, settings)
            self.mods = self.mods or {}
            self.mods[targetModUUID] = self.mods[targetModUUID] or {}
            self.mods[targetModUUID].settingsValues = settings
        end)
        ctx.stub(ModEventManager, "Emit", function(...) end)

        MCMAPI:SetEnumChoices("dynamic-enum", { "option-1", "option-2" }, nil, modUUID)

        D.expect(blueprint:GetAllSettings()["dynamic-enum"]:GetOptions().Choices).toEqual({ "option-1", "option-2" })
        D.expect(mods[modUUID].settingsValues["dynamic-enum"]).toBe("option-1")
    end)

    D.test("TestSetEnumChoicesShouldPreserveValidValue", function(ctx)
        local modUUID, blueprint, mods = CreateDynamicEnumBlueprint("option-1", "option-1")

        MCMAPI.mods = mods
        ModConfig.mods = {}
        ctx.stub(ModConfig, "UpdateAllSettingsForMod", function(self, targetModUUID, settings)
            self.mods = self.mods or {}
            self.mods[targetModUUID] = self.mods[targetModUUID] or {}
            self.mods[targetModUUID].settingsValues = settings
        end)
        ctx.stub(ModEventManager, "Emit", function(...) end)

        MCMAPI:SetEnumChoices("dynamic-enum", { "option-1", "option-2" }, nil, modUUID)

        D.expect(blueprint:GetAllSettings()["dynamic-enum"]:GetOptions().Choices).toEqual({ "option-1", "option-2" })
        D.expect(mods[modUUID].settingsValues["dynamic-enum"]).toBe("option-1")
    end)

    D.test("TestPublicFacadeSetReadsBackAndDeliversSavedEvent", function(ctx)
        ctx.requireClient()

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
        local initialValue
        local setResult
        local readbackValue
        local facadeTable = {}
        local publicMCM

        previousClientMods = MCMClientState.mods
        capturedClientMods = true
        MCMAPI.mods = { [modUUID] = mod }
        ModConfig.mods = { [modUUID] = mod }
        MCMClientState.mods = {}
        ctx.stub(MCMProxy, "IsMainMenu", function() return true end)
        ctx.stub(ModConfig, "SaveSettingsForMod", function() end)
        subscriptionIndex = ModEventManager:Subscribe(EventChannels.MCM_SETTING_SAVED, function(eventData)
            table.insert(receivedEvents, eventData)
        end)
        publicMCM = TableInjector.injectSharedMCMTable(facadeTable, modUUID)

        initialValue = publicMCM.Get(settingId)
        setResult = publicMCM.Set({
            settingId = settingId,
            value = false,
            shouldEmitEvent = true,
        })
        readbackValue = publicMCM.Get(settingId)

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

    D.test("TestSameSettingIdIsScopedPerMod", function(ctx)
        local firstModUUID = TestConstants.ModuleUUIDs[1]
        local secondModUUID = TestConstants.ModuleUUIDs[2]
        local settingId = "shared-setting-id"
        local function makeBlueprint(modUUID, defaultValue)
            return Blueprint:New({
                ModUUID = modUUID,
                SchemaVersion = 1,
                Settings = {
                    BlueprintSetting:New({
                        Id = settingId,
                        Name = "Shared Setting ID",
                        Type = "checkbox",
                        Default = defaultValue,
                    })
                }
            })
        end

        local mods = {
            [firstModUUID] = {
                blueprint = makeBlueprint(firstModUUID, false),
                settingsValues = {
                    [settingId] = false,
                },
            },
            [secondModUUID] = {
                blueprint = makeBlueprint(secondModUUID, true),
                settingsValues = {
                    [settingId] = false,
                },
            },
        }

        MCMAPI.mods = mods
        ModConfig.mods = mods
        ctx.stub(ModConfig, "UpdateAllSettingsForMod", function(self, targetModUUID, settings)
            self.mods[targetModUUID].settingsValues = settings
        end)
        ctx.stub(ModEventManager, "Emit", function(...) end)

        D.expect(MCMAPI:GetSettingValue(settingId, firstModUUID)).toBe(false)
        D.expect(MCMAPI:GetSettingValue(settingId, secondModUUID)).toBe(false)

        local success = MCMAPI:SetSettingValue(settingId, true, firstModUUID, false)

        D.expect(success).toBe(true)
        D.expect(MCMAPI:GetSettingValue(settingId, firstModUUID)).toBe(true)
        D.expect(MCMAPI:GetSettingValue(settingId, secondModUUID)).toBe(false)
    end)

    D.test("TestSetKeybindingV2UsesReplacementValue", function(ctx)
        local modUUID = TestConstants.ModuleUUIDs[1]
        local settingId = "canonical-keybinding"
        local blueprint = Blueprint:New({
            ModUUID = modUUID,
            SchemaVersion = 1,
            Settings = {
                BlueprintSetting:New({
                    Id = settingId,
                    Name = "Canonical keybinding",
                    Type = "keybinding_v2",
                    Default = { Keyboard = { Key = "K", ModifierKeys = {} } }
                })
            }
        })
        local mods = {
            [modUUID] = {
                blueprint = blueprint,
                settingsValues = {
                    [settingId] = {
                        Mouse = { Button = 5, ModifierKeys = { "LCTRL" } },
                        Enabled = false,
                        AllowConflict = true
                    }
                }
            }
        }
        MCMAPI.mods = mods
        ModConfig.mods = mods
        ctx.stub(ModConfig, "UpdateAllSettingsForMod", function(self, targetModUUID, settings)
            self.mods[targetModUUID].settingsValues = settings
        end)
        ctx.stub(ModEventManager, "Emit", function(...) end)

        local replacement = {
            Keyboard = { Key = "J", ModifierKeys = { "RSHIFT", "LALT" } },
            Enabled = true,
            AllowConflict = false
        }
        local success = MCMAPI:SetSettingValue(settingId, replacement, modUUID, false)
        D.expect(success).toBe(true)
        D.expect(MCMAPI:GetSettingValue(settingId, modUUID)).toEqual({
            Keyboard = { Key = "J", ModifierKeys = { "RSHIFT", "LALT" } },
            Enabled = true,
            AllowConflict = false,
        })
    end)
end)

D.describe("List default lifecycle", { tags = { "list-default-lifecycle" } }, function()
    local uuid, authorDefault, blueprint, mod

    D.beforeEach(function(ctx)
        ctx.requireServer()
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
        ctx.requireServer()
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

D.describe("List enabled client dispatch", { tags = { "list-enabled-client" } }, function()
    D.test("returns receipt and leaves current value for server authority", function(ctx)
        ctx.requireClient()
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
        D.expect(current.elements[1].enabled).toBe(true)
    end)
end)
