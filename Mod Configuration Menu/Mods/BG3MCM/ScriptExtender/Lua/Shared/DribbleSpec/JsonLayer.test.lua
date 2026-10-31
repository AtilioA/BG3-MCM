local StorageSyncService = Ext.Require("Shared/DynamicSettings/Services/StorageSyncService.lua")
local JsonAdapter = Ext.Require("Shared/DynamicSettings/Adapters/JsonAdapter.lua")
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local NewStorageSyncStateFixture = Ext.Require("Shared/DribbleSpec/Fixtures/Sandbox.lua")

-- Kept below the MCM package so the loader reads test data through Ext.IO.
local fixtureRoot = "BG3MCM/ScriptExtender/Lua/Shared/DribbleSpec/Fixtures"

local function fixtureModData(directory)
    return {
        Info = {
            Directory = fixtureRoot .. "/" .. directory,
            Name = "DribbleSpec Fixture Mod",
            Author = "DribbleSpec Fixture Author",
            ModuleUUID = ModuleUUID,
        },
    }
end

D.describe("JsonLayer", { tags = { "json-layer", "blueprint", "unit" } }, function()
    local syncStateFixture = NewStorageSyncStateFixture(StorageSyncService, JsonAdapter, SettingsService)

    D.beforeEach(function(ctx)
        syncStateFixture:Isolate(ctx)
    end)

    D.afterEach(function()
        syncStateFixture:Restore()
    end)

    D.test("formats malformed blueprint error details", function()
        local ok, err = pcall(function()
            JsonLayer:JSONParseError(
                "Failed to load MCM blueprint JSON file for mod: %s. Please contact %s about this issue.",
                "Example Mod",
                "Example Author")
        end)

        D.expect(ok).toBe(false)
        D.expect(err.code).toBe("JSONParseError")
        D.expect(err.message).toBe(
            "Failed to load MCM blueprint JSON file for mod: Example Mod. Please contact Example Author about this issue.")
    end)

    D.test("formats missing blueprint error details", function()
        local ok, err = pcall(function()
            JsonLayer:FileNotFoundError("Blueprint file not found for mod: %s", "Example Mod")
        end)

        D.expect(ok).toBe(false)
        D.expect(err.code).toBe("FileNotFoundError")
        D.expect(err.message).toBe("Blueprint file not found for mod: Example Mod")
    end)

    D.test("LoadBlueprintForMod reports a missing fixture with mod context", function()
        local ok, err = pcall(function()
            JsonLayer:LoadBlueprintForMod(fixtureModData("Missing"))
        end)

        D.expect(ok).toBe(false)
        D.expect(err.code).toBe("FileNotFoundError")
        D.expect(err.message).toBe("Blueprint file not found for mod: DribbleSpec Fixture Mod")
    end)

    D.test("LoadBlueprintForMod reports malformed fixture with mod and author context", function()
        local ok, err = pcall(function()
            JsonLayer:LoadBlueprintForMod(fixtureModData("Malformed"))
        end)

        D.expect(ok).toBe(false)
        D.expect(err.code).toBe("JSONParseError")
        D.expect(err.message).toBe(
            "Failed to load MCM blueprint JSON file for mod: DribbleSpec Fixture Mod. " ..
            "Blueprint is present but malformed. Please contact DribbleSpec Fixture Author about this issue.")
    end)

    D.test("LoadBlueprintForMod parses the packaged fixture file", function()
        local data = JsonLayer:LoadBlueprintForMod(fixtureModData("Valid"))

        D.expect(data.SchemaVersion).toBe(1)
        D.expect(data.ModName).toBe("Loader Fixture")
        D.expect(data.Settings[1].Id).toBe("loader-fixture-checkbox")
        D.expect(data.Settings[1].Default).toBe(true)
    end)

    D.test("LoadJSONFile parses a file and returns nil for a malformed one", function()
        syncStateFixture.files["DribbleSpec/valid.json"] = '{"a":1}'
        syncStateFixture.files["DribbleSpec/malformed.json"] = "{"

        D.expect(JsonLayer:LoadJSONFile("DribbleSpec/valid.json")).toEqual({ a = 1 })
        D.expect(JsonLayer:LoadJSONFile("DribbleSpec/malformed.json")).toBeNil()
    end)

    D.test("TryParseModBlueprintJSON parses JSON, and returns nil without a mod UUID or for malformed JSON", function()
        D.expect(JsonLayer:TryParseModBlueprintJSON('{"a":1}', ModuleUUID)).toEqual({ a = 1 })
        D.expect(JsonLayer:TryParseModBlueprintJSON("{}", nil)).toBeNil()
        D.expect(JsonLayer:TryParseModBlueprintJSON("{", ModuleUUID)).toBeNil()
    end)

    D.test("LoadBlueprintForMod rejects mod data without a directory", function()
        for _, modData in ipairs({ false, {}, { Info = {} } }) do
            local ok, err = pcall(function()
                JsonLayer:LoadBlueprintForMod(modData or nil)
            end)

            D.expect(ok).toBe(false)
            D.expect(err.code).toBe("FileNotFoundError")
        end
    end)

    D.test("LoadBlueprintForMod rejects JSON that is not a table", function()
        local modData = fixtureModData("Sandbox")
        syncStateFixture.files["Mods/" .. modData.Info.Directory .. "/MCM_blueprint.json"] = "1"

        local ok, err = pcall(function()
            JsonLayer:LoadBlueprintForMod(modData)
        end)

        D.expect(ok).toBe(false)
        D.expect(err.code).toBe("JSONParseError")
    end)

    D.describe("misplaced blueprint warning", function()
        local warnings

        D.beforeEach(function(ctx)
            warnings = {}
            ctx.stub(Mods.BG3MCM, "MCMWarn", function(_level, message)
                table.insert(warnings, message)
            end)
        end)

        D.test("warns when a blueprint is in the ScriptExtender folder", function()
            local modData = fixtureModData("Valid")
            syncStateFixture.files["Mods/" .. modData.Info.Directory .. "/ScriptExtender/MCM_blueprint.json"] = "{}"

            JsonLayer:LoadBlueprintForMod(modData)

            D.expect(warnings).toEqual({
                "MCM_blueprint.json found in incorrect location for mod %s. Please move it alongside the mod's meta.lsx file.",
            })
        end)

        D.test("stays quiet when the blueprint is only in the mod folder", function()
            JsonLayer:LoadBlueprintForMod(fixtureModData("Valid"))

            D.expect(warnings).toEqual({})
        end)
    end)

    D.test("FlattenSettingsJSON lifts nested values and keeps preserved tables", function()
        local flat = JsonLayer:FlattenSettingsJSON({
            a = 1,
            tab = { b = 2, keep = { x = 1 } },
        }, function(key)
            return key == "keep"
        end)

        D.expect(flat).toEqual({ a = 1, b = 2, keep = { x = 1 } })
    end)
end)
