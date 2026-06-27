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
        local setSettingValueCalled = false

        MCMAPI.mods = mods
        ModConfig.mods = {}
        ModConfig.UpdateAllSettingsForMod = function(self, targetModUUID, settings)
            setSettingValueCalled = true
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
        D.expect(setSettingValueCalled).toBeFalsy()
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
end)
