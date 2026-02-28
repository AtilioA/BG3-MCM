TestSuite.RegisterTests("ModConfig", {
    -- Blueprint structure validation
    "TestAddKeysMissingFromBlueprintShouldUseOldIdOnlyIfNoValueOnCurrentId",
    "TestAddKeysMissingFromBlueprintShouldUseNotOldIdOnlyIfValueOnCurrentId",
    "TestSaveSettingsForModShouldPersistRootSettings",
    "TestSaveSettingsForModShouldFallbackToRootDefault",
})

function TestAddKeysMissingFromBlueprintShouldUseOldIdOnlyIfNoValueOnCurrentId()
    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Settings = {
            {
                Id = "setting2",
                OldId = "setting1",
                Type = "string",
                Default = "def"
            }
        }
    })
    local oldValue = "toto"
    local settings = {
        setting1 = oldValue,
    }

    ModConfig:AddKeysMissingFromBlueprint(blueprint, settings)

    TestSuite.AssertEquals(settings["setting2"], oldValue)
    TestSuite.AssertEquals(settings["setting1"], oldValue) --will be removed during RemoveDeprecatedKeys
end

function TestAddKeysMissingFromBlueprintShouldUseNotOldIdOnlyIfValueOnCurrentId()
    local blueprint = Blueprint:New({
        SchemaVersion = 1,
        Settings = {
            {
                Id = "setting2",
                OldId = "setting1",
                Type = "string",
                Default = "def"
            }
        }
    })
    local value = "titi"
    local oldValue = "toto"
    local settings = {
        setting1 = oldValue,
        setting2 = value,
    }

    ModConfig:AddKeysMissingFromBlueprint(blueprint, settings)

    TestSuite.AssertEquals(settings["setting2"], value)
    TestSuite.AssertEquals(settings["setting1"], oldValue) --will be removed during RemoveDeprecatedKeys
end

function TestSaveSettingsForModShouldPersistRootSettings()
    local modUUID = TestConstants.ModuleUUIDs[1]
    local rawData = {
        SchemaVersion = 1,
        Settings = {
            {
                Id = "root-setting",
                Name = "Root Setting",
                Type = "checkbox",
                Default = true,
            }
        }
    }

    local preprocessedData = DataPreprocessing:PreprocessData(rawData, modUUID)
    local blueprint = Blueprint:New(preprocessedData)

    local originalMods = ModConfig.mods
    local originalGetSettingsFilePath = ModConfig.GetSettingsFilePath
    local originalSaveJSONFile = JsonLayer.SaveJSONFile
    local capturedPath = nil
    local capturedData = nil

    ModConfig.mods = {
        [modUUID] = {
            blueprint = blueprint,
            settingsValues = {
                ["root-setting"] = false,
            }
        }
    }

    ModConfig.GetSettingsFilePath = function(_self, _modUUID)
        return "mock/settings.json"
    end

    JsonLayer.SaveJSONFile = function(_self, path, data)
        capturedPath = path
        capturedData = data
    end

    local ok, err = pcall(function()
        ModConfig:SaveSettingsForMod(modUUID)
    end)

    ModConfig.mods = originalMods
    ModConfig.GetSettingsFilePath = originalGetSettingsFilePath
    JsonLayer.SaveJSONFile = originalSaveJSONFile

    if not ok then
        error(err)
    end

    TestSuite.AssertEquals(capturedPath, "mock/settings.json")
    TestSuite.AssertEquals(capturedData["root-setting"], false)
end

function TestSaveSettingsForModShouldFallbackToRootDefault()
    local modUUID = TestConstants.ModuleUUIDs[1]
    local rawData = {
        SchemaVersion = 1,
        Settings = {
            {
                Id = "root-setting",
                Name = "Root Setting",
                Type = "checkbox",
                Default = true,
            }
        }
    }

    local preprocessedData = DataPreprocessing:PreprocessData(rawData, modUUID)
    local blueprint = Blueprint:New(preprocessedData)

    local originalMods = ModConfig.mods
    local originalGetSettingsFilePath = ModConfig.GetSettingsFilePath
    local originalSaveJSONFile = JsonLayer.SaveJSONFile
    local capturedData = nil

    ModConfig.mods = {
        [modUUID] = {
            blueprint = blueprint,
            settingsValues = {}
        }
    }

    ModConfig.GetSettingsFilePath = function(_self, _modUUID)
        return "mock/settings.json"
    end

    JsonLayer.SaveJSONFile = function(_self, _path, data)
        capturedData = data
    end

    local ok, err = pcall(function()
        ModConfig:SaveSettingsForMod(modUUID)
    end)

    ModConfig.mods = originalMods
    ModConfig.GetSettingsFilePath = originalGetSettingsFilePath
    JsonLayer.SaveJSONFile = originalSaveJSONFile

    if not ok then
        error(err)
    end

    TestSuite.AssertEquals(capturedData["root-setting"], true)
end
