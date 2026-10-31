local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")

D.describe("Blueprint HiddenFromList", { tags = { "mod_list_visibility", "data-preprocessing", "preprocessing", "unit" } }, function()
    -- Mutation runs list "client": a mutant can reach any write or send, so both are sandboxed deny-by-default.
    local sandbox = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function(ctx)
        sandbox:Isolate(ctx)
    end)

    D.afterEach(function()
        sandbox:Restore()
    end)

    --- Run a mock blueprint through the real preprocessing, construction, and sanitizing pipeline
    ---@param hiddenFromList boolean|nil Top-level HiddenFromList, or nil to omit it
    ---@return Blueprint|nil
    local function sanitizeMockBlueprint(hiddenFromList)
        local rawData = {
            SchemaVersion = 1,
            HiddenFromList = hiddenFromList,
            Settings = {
                { Id = "setting-1", Name = "Setting 1", Type = "checkbox", Default = true },
            },
        }
        local modUUID = TestConstants.ModuleUUIDs[1]
        local blueprint = Blueprint:New(DataPreprocessing:PreprocessData(rawData, modUUID))
        return BlueprintPreprocessing:SanitizeBlueprint(blueprint, modUUID)
    end

    D.test("defaults to false when the blueprint omits it", function()
        D.expect(sanitizeMockBlueprint(nil):GetHiddenFromList()).toBe(false)
    end)

    D.test("exposes true from the blueprint", function()
        D.expect(sanitizeMockBlueprint(true):GetHiddenFromList()).toBe(true)
    end)

    D.test("exposes explicit false from the blueprint", function()
        D.expect(sanitizeMockBlueprint(false):GetHiddenFromList()).toBe(false)
    end)
end)
