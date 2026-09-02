D.describe("JsonLayer", { tags = { "json-layer", "unit" } }, function()
    D.test("formats malformed blueprint error details", function()
        local ok, err = pcall(function()
            JsonLayer:JSONParseError(
                "Failed to load MCM blueprint JSON file for mod: %s. Please contact %s about this issue.",
                "Example Mod",
                "Example Author")
        end)

        D.expect(ok).toBeFalsy()
        D.expect(err.code).toBe("JSONParseError")
        D.expect(err.message).toBe(
            "Failed to load MCM blueprint JSON file for mod: Example Mod. Please contact Example Author about this issue.")
    end)

    D.test("formats missing blueprint error details", function()
        local ok, err = pcall(function()
            JsonLayer:FileNotFoundError("Blueprint file not found for mod: %s", "Example Mod")
        end)

        D.expect(ok).toBeFalsy()
        D.expect(err.code).toBe("FileNotFoundError")
        D.expect(err.message).toBe("Blueprint file not found for mod: Example Mod")
    end)
end)
