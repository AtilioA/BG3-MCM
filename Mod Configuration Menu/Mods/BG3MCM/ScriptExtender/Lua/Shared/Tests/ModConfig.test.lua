TestSuite.RegisterTests("ModConfig", {
    -- Blueprint structure validation
    "TestAddKeysMissingFromBlueprintShouldUseOldIdOnlyIfNoValueOnCurrentId",
    "TestAddKeysMissingFromBlueprintShouldUseNotOldIdOnlyIfValueOnCurrentId"
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