local function makeBlueprint()
    local blueprint = Blueprint:New({
        ModUUID = TestConstants.ModuleUUIDs[1],
        SchemaVersion = 1,
        Settings = {
            {
                Id = "root-setting",
                Name = "Root Setting",
                Type = "checkbox",
                Default = true,
            },
        },
        Tabs = {
            {
                TabId = "main-tab",
                TabName = "Main",
                Tabs = {
                    {
                        TabId = "nested-tab",
                        TabName = "Nested",
                        Settings = {
                            {
                                Id = "nested-setting",
                                Name = "Nested Setting",
                                Type = "text",
                                Default = "nested",
                            },
                        },
                    },
                },
            },
        },
    })
    -- Cache tests start cold regardless of constructor traversal.
    BlueprintCache:Invalidate(blueprint)
    return blueprint
end

    D.describe("BlueprintCache", { tags = { "blueprint-cache", "unit" } }, function()
    local originalModConfigMods

    D.beforeEach(function()
        originalModConfigMods = ModConfig.mods
        BlueprintCache:SetCacheEnabled(true)
        BlueprintCache:InvalidateAll()
    end)

    D.afterEach(function()
        ModConfig.mods = originalModConfigMods
        BlueprintCache:SetCacheEnabled(true)
        BlueprintCache:InvalidateAll()
    end)

    D.test("TestBlueprintCacheReturnsSettingsWhenEnabled", function()
        local blueprint = makeBlueprint()

        D.expect(blueprint:GetSettingById("root-setting"):GetDefault()).toBe(true)
        D.expect(blueprint:GetAllSettings()["nested-setting"]:GetDefault()).toBe("nested")
    end)

    D.test("TestBlueprintCacheReturnsSettingsWhenDisabled", function()
        local blueprint = makeBlueprint()

        BlueprintCache:SetCacheEnabled(false)

        D.expect(blueprint:GetSettingById("root-setting"):GetDefault()).toBe(true)
        D.expect(blueprint:GetAllSettings()["nested-setting"]:GetDefault()).toBe("nested")
    end)

    D.test("TestBlueprintCacheAppliesDebugDisableSetting", function(ctx)
        ctx.stub(MCMAPI, "GetSettingValue", function(_self, settingId, _modUUID)
            if settingId == "debug_level" then
                return 1
            end

            if settingId == "enable_blueprint_cache" then
                return false
            end
        end)

        BlueprintCache:ApplyMCMSettings()

        D.expect(BlueprintCache:IsCacheEnabled()).toBe(false)
    end)

    D.test("TestBlueprintCacheIgnoresDisableSettingWhenDebugHidden", function(ctx)
        ctx.stub(MCMAPI, "GetSettingValue", function(_self, settingId, _modUUID)
            if settingId == "debug_level" then
                return 0
            end

            if settingId == "enable_blueprint_cache" then
                return false
            end
        end)

        BlueprintCache:ApplyMCMSettings()

        D.expect(BlueprintCache:IsCacheEnabled()).toBe(true)
    end)

    D.test("TestBlueprintCacheMissingSettingStaysEnabled", function(ctx)
        ctx.stub(MCMAPI, "GetSettingValue", function(_self, settingId, _modUUID)
            if settingId == "debug_level" then
                return 1
            end
        end)

        BlueprintCache:ApplyMCMSettings()

        D.expect(BlueprintCache:IsCacheEnabled()).toBe(true)
    end)

    D.test("TestBlueprintCacheInvalidatesAfterAddSetting", function()
        local blueprint = makeBlueprint()

        blueprint:GetAllSettings()
        blueprint:AddSetting({
            Id = "added-setting",
            Name = "Added Setting",
            Type = "checkbox",
            Default = false,
        })

        D.expect(blueprint:GetSettingById("added-setting")).Not.toBeNil()
    end)

    D.test("TestBlueprintCacheInvalidatesAfterSetSettings", function()
        local blueprint = makeBlueprint()

        blueprint:GetAllSettings()
        blueprint:SetSettings({
            BlueprintSetting:New({
                Id = "replacement-setting",
                Name = "Replacement Setting",
                Type = "checkbox",
                Default = false,
            }),
        })

        D.expect(blueprint:GetSettingById("root-setting")).toBeNil()
        D.expect(blueprint:GetSettingById("replacement-setting")).Not.toBeNil()
    end)

    D.test("TestBlueprintCacheDoesNotNeedInvalidationForOptionMutation", function()
        local blueprint = Blueprint:New({
            ModUUID = TestConstants.ModuleUUIDs[1],
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "dynamic-enum",
                    Name = "Dynamic Enum",
                    Type = "enum",
                    Default = "option-1",
                    Options = {
                        Dynamic = true,
                        Choices = { "option-1" },
                    },
                },
            },
        })
        BlueprintCache:Invalidate(blueprint)

        local setting = blueprint:GetSettingById("dynamic-enum")
        setting:GetOptions().Choices = { "option-1", "option-2" }

        D.expect(blueprint:GetSettingById("dynamic-enum"):GetOptions().Choices).toEqual({ "option-1", "option-2" })
    end)

    D.test("TestBlueprintCacheStoresNestedPaths", function()
        local blueprint = makeBlueprint()
        local path = BlueprintShape:GetPathForSetting(blueprint, "nested-setting")

        D.expect(path).toEqual({ "main-tab", "nested-tab" })
    end)

    D.test("TestBlueprintCacheOrderedTraversalPreservesSettingOrder", function()
        local blueprint = Blueprint:New({
            ModUUID = TestConstants.ModuleUUIDs[1],
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "first-setting",
                    Name = "First Setting",
                    Type = "checkbox",
                    Default = true,
                },
                {
                    Id = "second-setting",
                    Name = "Second Setting",
                    Type = "checkbox",
                    Default = false,
                },
            },
        })

        local ordered = blueprint:GetAllSettingsOrdered()
        local byId = blueprint:GetAllSettings()

        D.expect(#ordered).toBe(2)
        D.expect(ordered[1]:GetName()).toBe("First Setting")
        D.expect(ordered[2]:GetName()).toBe("Second Setting")
        D.expect(byId["first-setting"]:GetName()).toBe("First Setting")
        D.expect(byId["second-setting"]:GetName()).toBe("Second Setting")
    end)

    D.test("TestSaveSettingsForModUsesWarmedBlueprintCache", function(ctx)
        local modUUID = TestConstants.ModuleUUIDs[1]
        local blueprint = makeBlueprint()
        local savedPath
        local savedData

        blueprint:GetAllSettings()

        ModConfig.mods = {
            [modUUID] = {
                blueprint = blueprint,
                settingsValues = {
                    ["root-setting"] = false,
                    ["nested-setting"] = "saved",
                },
            },
        }
        ctx.stub(ModConfig, "GetSettingsFilePath", function(_self, _modUUID)
            return "mock/settings.json"
        end)
        ctx.stub(JsonLayer, "SaveJSONFile", function(_self, path, data)
            savedPath = path
            savedData = data
        end)

        ModConfig:SaveSettingsForMod(modUUID)

        D.expect(savedPath).toBe("mock/settings.json")
        D.expect(savedData).toEqual({
            ["root-setting"] = false,
            ["main-tab"] = { ["nested-tab"] = { ["nested-setting"] = "saved" } },
        })
    end)

    D.test("TestBlueprintCacheDoesNotExposeMutableAllSettingsMap", function()
        local blueprint = makeBlueprint()

        local allSettings = blueprint:GetAllSettings()
        allSettings["root-setting"] = nil

        D.expect(blueprint:GetSettingById("root-setting")).Not.toBeNil()
    end)
end)
