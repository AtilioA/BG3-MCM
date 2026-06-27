local function makeBlueprint()
    return Blueprint:New({
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
end

D.describe("BlueprintCache", { tags = { "blueprint-cache", "unit" } }, function()
    D.beforeEach(function()
        BlueprintCache:SetEnabled(true)
        BlueprintCache:InvalidateAll()
    end)

    D.afterEach(function()
        BlueprintCache:SetEnabled(true)
        BlueprintCache:InvalidateAll()
    end)

    D.test("TestBlueprintCacheBuildsOnceWhenEnabled", function(ctx)
        local blueprint = makeBlueprint()
        local spy = ctx.spyOn(BlueprintShape, "_BuildIndex")

        blueprint:GetAllSettings()
        blueprint:GetAllSettings()

        ctx.expect(spy).toHaveBeenCalledTimes(1)
    end)

    D.test("TestBlueprintCacheCanBeDisabled", function(ctx)
        local blueprint = makeBlueprint()
        local spy = ctx.spyOn(BlueprintShape, "_BuildIndex")

        BlueprintCache:SetEnabled(false)
        blueprint:GetAllSettings()
        blueprint:GetAllSettings()

        ctx.expect(spy).toHaveBeenCalledTimes(2)
    end)

    D.test("TestBlueprintCacheAppliesDebugDisableSetting", function()
        local originalMCMAPI = MCMAPI
        MCMAPI = {
            GetSettingValue = function(_self, settingId, _modUUID)
                if settingId == "debug_level" then
                    return 1
                end

                if settingId == "enable_blueprint_cache" then
                    return false
                end
            end,
        }

        local ok, err = pcall(function()
            BlueprintCache:ApplyMCMSettings()
        end)

        MCMAPI = originalMCMAPI

        if not ok then
            error(err)
        end

        D.expect(BlueprintCache:IsEnabled()).toBe(false)
    end)

    D.test("TestBlueprintCacheIgnoresDisableSettingWhenDebugHidden", function()
        local originalMCMAPI = MCMAPI
        MCMAPI = {
            GetSettingValue = function(_self, settingId, _modUUID)
                if settingId == "debug_level" then
                    return 0
                end

                if settingId == "enable_blueprint_cache" then
                    return false
                end
            end,
        }

        local ok, err = pcall(function()
            BlueprintCache:ApplyMCMSettings()
        end)

        MCMAPI = originalMCMAPI

        if not ok then
            error(err)
        end

        D.expect(BlueprintCache:IsEnabled()).toBe(true)
    end)

    D.test("TestBlueprintCacheInvalidatesAfterAddSetting", function(ctx)
        local blueprint = makeBlueprint()
        local spy = ctx.spyOn(BlueprintShape, "_BuildIndex")

        blueprint:GetAllSettings()
        blueprint:AddSetting({
            Id = "added-setting",
            Name = "Added Setting",
            Type = "checkbox",
            Default = false,
        })

        D.expect(blueprint:GetSettingById("added-setting")).Not.toBeNil()
        ctx.expect(spy).toHaveBeenCalledTimes(2)
    end)

    D.test("TestBlueprintCacheInvalidatesAfterSetSettings", function(ctx)
        local blueprint = makeBlueprint()
        local spy = ctx.spyOn(BlueprintShape, "_BuildIndex")

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
        ctx.expect(spy).toHaveBeenCalledTimes(2)
    end)

    D.test("TestBlueprintCacheDoesNotNeedInvalidationForOptionMutation", function(ctx)
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
        local spy = ctx.spyOn(BlueprintShape, "_BuildIndex")

        local setting = blueprint:GetSettingById("dynamic-enum")
        setting:GetOptions().Choices = { "option-1", "option-2" }

        D.expect(blueprint:GetSettingById("dynamic-enum"):GetOptions().Choices).toEqual({ "option-1", "option-2" })
        ctx.expect(spy).toHaveBeenCalledTimes(1)
    end)

    D.test("TestBlueprintCacheStoresNestedPaths", function()
        local blueprint = makeBlueprint()
        local path = BlueprintShape:GetPathForSetting(blueprint, "nested-setting")

        D.expect(path).toEqual({ "main-tab", "nested-tab" })
    end)

    D.test("TestBlueprintCacheOrderedTraversalPreservesDuplicateSettings", function()
        local blueprint = Blueprint:New({
            ModUUID = TestConstants.ModuleUUIDs[1],
            SchemaVersion = 1,
            Settings = {
                {
                    Id = "duplicate-setting",
                    Name = "First Duplicate",
                    Type = "checkbox",
                    Default = true,
                },
                {
                    Id = "duplicate-setting",
                    Name = "Second Duplicate",
                    Type = "checkbox",
                    Default = false,
                },
            },
        })

        local ordered = blueprint:GetAllSettingsOrdered()
        local byId = blueprint:GetAllSettings()

        D.expect(#ordered).toBe(2)
        D.expect(ordered[1]:GetName()).toBe("First Duplicate")
        D.expect(ordered[2]:GetName()).toBe("Second Duplicate")
        D.expect(byId["duplicate-setting"]:GetName()).toBe("Second Duplicate")
    end)

    D.test("TestSaveSettingsForModUsesWarmedBlueprintCache", function(ctx)
        local modUUID = TestConstants.ModuleUUIDs[1]
        local blueprint = makeBlueprint()
        local originalMods = ModConfig.mods
        local originalGetSettingsFilePath = ModConfig.GetSettingsFilePath
        local originalSaveJSONFile = JsonLayer.SaveJSONFile

        blueprint:GetAllSettings()
        local spy = ctx.spyOn(BlueprintShape, "_BuildIndex")

        ModConfig.mods = {
            [modUUID] = {
                blueprint = blueprint,
                settingsValues = {
                    ["root-setting"] = false,
                    ["nested-setting"] = "saved",
                },
            },
        }
        ModConfig.GetSettingsFilePath = function(_self, _modUUID)
            return "mock/settings.json"
        end
        JsonLayer.SaveJSONFile = function() end

        local ok, err = pcall(function()
            ModConfig:SaveSettingsForMod(modUUID)
        end)

        ModConfig.mods = originalMods
        ModConfig.GetSettingsFilePath = originalGetSettingsFilePath
        JsonLayer.SaveJSONFile = originalSaveJSONFile

        if not ok then
            error(err)
        end

        ctx.expect(spy).toHaveBeenCalledTimes(0)
    end)

    D.test("TestBlueprintCacheDoesNotExposeMutableAllSettingsMap", function(ctx)
        local blueprint = makeBlueprint()
        local spy = ctx.spyOn(BlueprintShape, "_BuildIndex")

        local allSettings = blueprint:GetAllSettings()
        allSettings["root-setting"] = nil

        D.expect(blueprint:GetSettingById("root-setting")).Not.toBeNil()
        ctx.expect(spy).toHaveBeenCalledTimes(1)
    end)

    D.test("TestBlueprintCacheIsNotStoredOnBlueprintObjects", function()
        local blueprint = makeBlueprint()

        blueprint:GetAllSettings()

        D.expect(blueprint.byId).toBeNil()
        D.expect(blueprint.entries).toBeNil()
        D.expect(blueprint.pathById).toBeNil()
        D.expect(blueprint._cache).toBeNil()
    end)
end)
