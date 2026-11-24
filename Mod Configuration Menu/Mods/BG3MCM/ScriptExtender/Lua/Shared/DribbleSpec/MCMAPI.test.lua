D.describe("MCMAPI", { tags = { "mcmapi", "unit" } }, function()
    local originalMCMAPIMods
    local originalModConfigMods

    D.beforeEach(function()
        originalMCMAPIMods = MCMAPI.mods
        originalModConfigMods = ModConfig.mods
    end)

    D.afterEach(function()
        MCMAPI.mods = originalMCMAPIMods
        ModConfig.mods = originalModConfigMods
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

