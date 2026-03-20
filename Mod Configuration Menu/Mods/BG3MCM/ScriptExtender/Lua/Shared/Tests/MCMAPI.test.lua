TestSuite.RegisterTests("MCMAPI", {
    "TestSetEnumChoicesShouldFallbackInvalidValueToDefault",
    "TestSetEnumChoicesShouldFallbackInvalidValueToFirstChoiceWhenDefaultIsUnavailable",
    "TestSetEnumChoicesShouldPreserveValidValue",
})

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

function TestSetEnumChoicesShouldFallbackInvalidValueToDefault()
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
        MCMAPI:SetEnumChoices("dynamic-enum", { "option-1", "option-2" }, modUUID)
    end)

    MCMAPI.mods = originalMods
    ModConfig.mods = originalModConfigMods
    ModConfig.UpdateAllSettingsForMod = originalUpdateAllSettingsForMod
    ModEventManager.Emit = originalEmit

    if not ok then
        error(err)
    end

    TestSuite.AssertEquals(blueprint:GetAllSettings()["dynamic-enum"]:GetOptions().Choices, { "option-1", "option-2" })
    TestSuite.AssertEquals(mods[modUUID].settingsValues["dynamic-enum"], "option-2")
end

function TestSetEnumChoicesShouldFallbackInvalidValueToFirstChoiceWhenDefaultIsUnavailable()
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
        MCMAPI:SetEnumChoices("dynamic-enum", { "option-1", "option-2" }, modUUID)
    end)

    MCMAPI.mods = originalMods
    ModConfig.mods = originalModConfigMods
    ModConfig.UpdateAllSettingsForMod = originalUpdateAllSettingsForMod
    ModEventManager.Emit = originalEmit

    if not ok then
        error(err)
    end

    TestSuite.AssertEquals(blueprint:GetAllSettings()["dynamic-enum"]:GetOptions().Choices, { "option-1", "option-2" })
    TestSuite.AssertEquals(mods[modUUID].settingsValues["dynamic-enum"], "option-1")
end

function TestSetEnumChoicesShouldPreserveValidValue()
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
        MCMAPI:SetEnumChoices("dynamic-enum", { "option-1", "option-2" }, modUUID)
    end)

    MCMAPI.mods = originalMods
    ModConfig.mods = originalModConfigMods
    ModConfig.UpdateAllSettingsForMod = originalUpdateAllSettingsForMod
    ModEventManager.Emit = originalEmit

    if not ok then
        error(err)
    end

    TestSuite.AssertEquals(blueprint:GetAllSettings()["dynamic-enum"]:GetOptions().Choices, { "option-1", "option-2" })
    TestSuite.AssertEquals(mods[modUUID].settingsValues["dynamic-enum"], "option-1")
    TestSuite.AssertFalse(setSettingValueCalled)
end
