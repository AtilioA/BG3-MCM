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
