local TableInjector = Ext.Require("Shared/Helpers/MCM/GlobalTable/TableInjector.lua")

D.describe("MCMAPI", { tags = { "mcmapi", "unit" } }, function()
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

    D.test("TestSetEnumChoicesShouldFallbackInvalidValueToDefault", function()
        local modUUID, blueprint, mods = CreateDynamicEnumBlueprint("option-2", "manually-edited-value")
        local originalMods = MCMAPI.mods
        local originalModConfigMods = ModConfig.mods
        local originalUpdateAllSettingsForMod = ModConfig.UpdateAllSettingsForMod
        local originalEmit = ModEventManager.Emit

        MCMAPI.mods = mods
        ModConfig.mods = {}
        ModConfig.UpdateAllSettingsForMod = function(self, targetModUUID, settings)
            self.mods = self.mods or {}
            self.mods[targetModUUID] = self.mods[targetModUUID] or {}
            self.mods[targetModUUID].settingsValues = settings
        end
        ModEventManager.Emit = function(...) end

        local ok, err = pcall(function()
            MCMAPI:SetEnumChoices("dynamic-enum", { "option-1", "option-2" }, nil, modUUID)
        end)

        MCMAPI.mods = originalMods
        ModConfig.mods = originalModConfigMods
        ModConfig.UpdateAllSettingsForMod = originalUpdateAllSettingsForMod
        ModEventManager.Emit = originalEmit

        if not ok then
            error(err)
        end

        D.expect(blueprint:GetAllSettings()["dynamic-enum"]:GetOptions().Choices).toEqual({ "option-1", "option-2" })
        D.expect(mods[modUUID].settingsValues["dynamic-enum"]).toBe("option-2")
    end)

    D.test("TestSetEnumChoicesShouldFallbackInvalidValueToFirstChoiceWhenDefaultIsUnavailable", function()
        local modUUID, blueprint, mods = CreateDynamicEnumBlueprint("missing-default", "manually-edited-value")
        local originalMods = MCMAPI.mods
        local originalModConfigMods = ModConfig.mods
        local originalUpdateAllSettingsForMod = ModConfig.UpdateAllSettingsForMod
        local originalEmit = ModEventManager.Emit

        MCMAPI.mods = mods
        ModConfig.mods = {}
        ModConfig.UpdateAllSettingsForMod = function(self, targetModUUID, settings)
            self.mods = self.mods or {}
            self.mods[targetModUUID] = self.mods[targetModUUID] or {}
            self.mods[targetModUUID].settingsValues = settings
        end
        ModEventManager.Emit = function(...) end

        local ok, err = pcall(function()
            MCMAPI:SetEnumChoices("dynamic-enum", { "option-1", "option-2" }, nil, modUUID)
        end)

        MCMAPI.mods = originalMods
        ModConfig.mods = originalModConfigMods
        ModConfig.UpdateAllSettingsForMod = originalUpdateAllSettingsForMod
        ModEventManager.Emit = originalEmit

        if not ok then
            error(err)
        end

        D.expect(blueprint:GetAllSettings()["dynamic-enum"]:GetOptions().Choices).toEqual({ "option-1", "option-2" })
        D.expect(mods[modUUID].settingsValues["dynamic-enum"]).toBe("option-1")
    end)

    D.test("TestSetEnumChoicesShouldPreserveValidValue", function()
        local modUUID, blueprint, mods = CreateDynamicEnumBlueprint("option-1", "option-1")
        local originalMods = MCMAPI.mods
        local originalModConfigMods = ModConfig.mods
        local originalUpdateAllSettingsForMod = ModConfig.UpdateAllSettingsForMod
        local originalEmit = ModEventManager.Emit

        MCMAPI.mods = mods
        ModConfig.mods = {}
        ModConfig.UpdateAllSettingsForMod = function(self, targetModUUID, settings)
            self.mods = self.mods or {}
            self.mods[targetModUUID] = self.mods[targetModUUID] or {}
            self.mods[targetModUUID].settingsValues = settings
        end
        ModEventManager.Emit = function(...) end

        local ok, err = pcall(function()
            MCMAPI:SetEnumChoices("dynamic-enum", { "option-1", "option-2" }, nil, modUUID)
        end)

        MCMAPI.mods = originalMods
        ModConfig.mods = originalModConfigMods
        ModConfig.UpdateAllSettingsForMod = originalUpdateAllSettingsForMod
        ModEventManager.Emit = originalEmit

        if not ok then
            error(err)
        end

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
        local originalMods = MCMAPI.mods
        local originalModConfigMods = ModConfig.mods
        local receivedEvents = {}
        local subscriptionIndex
        local initialValue
        local setResult
        local readbackValue
        local facadeTable = {}
        local publicMCM

        local ok, err = pcall(function()
            MCMAPI.mods = { [modUUID] = mod }
            ModConfig.mods = { [modUUID] = mod }
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
        end)

        if subscriptionIndex then
            pcall(ModEventManager.Unsubscribe, ModEventManager, EventChannels.MCM_SETTING_SAVED, subscriptionIndex)
        end
        MCMAPI.mods = originalMods
        ModConfig.mods = originalModConfigMods

        if not ok then
            error(err)
        end

        D.expect(initialValue).toBe(true)
        D.expect(setResult).toBe(true)
        D.expect(readbackValue).toBe(false)
        D.expect(receivedEvents).toEqual({
            { modUUID = modUUID, settingId = settingId, value = false, oldValue = true },
        })
    end)

    D.test("TestSameSettingIdIsScopedPerMod", function()
        local firstModUUID = TestConstants.ModuleUUIDs[1]
        local secondModUUID = TestConstants.ModuleUUIDs[2]
        local settingId = "shared-setting-id"
        local originalMods = MCMAPI.mods
        local originalModConfigMods = ModConfig.mods
        local originalUpdateAllSettingsForMod = ModConfig.UpdateAllSettingsForMod
        local originalEmit = ModEventManager.Emit

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
        ModConfig.UpdateAllSettingsForMod = function(self, targetModUUID, settings)
            self.mods[targetModUUID].settingsValues = settings
        end
        ModEventManager.Emit = function(...) end

        local ok, err = pcall(function()
            D.expect(MCMAPI:GetSettingValue(settingId, firstModUUID)).toBe(false)
            D.expect(MCMAPI:GetSettingValue(settingId, secondModUUID)).toBe(false)

            local success = MCMAPI:SetSettingValue(settingId, true, firstModUUID, false)

            D.expect(success).toBe(true)
            D.expect(MCMAPI:GetSettingValue(settingId, firstModUUID)).toBe(true)
            D.expect(MCMAPI:GetSettingValue(settingId, secondModUUID)).toBe(false)
        end)

        MCMAPI.mods = originalMods
        ModConfig.mods = originalModConfigMods
        ModConfig.UpdateAllSettingsForMod = originalUpdateAllSettingsForMod
        ModEventManager.Emit = originalEmit

        if not ok then
            error(err)
        end
    end)

    D.test("TestSetKeybindingV2UsesReplacementValue", function()
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
        local originalMods = MCMAPI.mods
        local originalModConfigMods = ModConfig.mods
        local originalUpdateAllSettingsForMod = ModConfig.UpdateAllSettingsForMod
        local originalEmit = ModEventManager.Emit
        MCMAPI.mods = mods
        ModConfig.mods = mods
        ModConfig.UpdateAllSettingsForMod = function(self, targetModUUID, settings)
            self.mods[targetModUUID].settingsValues = settings
        end
        ModEventManager.Emit = function(...) end

        local ok, err = pcall(function()
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

        MCMAPI.mods = originalMods
        ModConfig.mods = originalModConfigMods
        ModConfig.UpdateAllSettingsForMod = originalUpdateAllSettingsForMod
        ModEventManager.Emit = originalEmit
        if not ok then error(err) end
    end)
end)
