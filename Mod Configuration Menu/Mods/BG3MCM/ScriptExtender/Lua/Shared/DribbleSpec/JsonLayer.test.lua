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

D.describe("JsonLayer", { tags = { "json-layer", "unit" } }, function()
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
end)
