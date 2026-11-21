D.describe("global IMGUI font", { tags = { "font", "client" } }, function()

    D.test("rejects an unknown typeface", function()
        local success, errorMessage = Font.ApplyGlobalFont("NotARealTypeface", "Default")
        D.expect(success).toBe(false)
        D.expect(errorMessage).toBe("Unknown font typeface 'NotARealTypeface'")
    end)

    D.test("rejects an unknown font size", function()
        local success, errorMessage = Font.ApplyGlobalFont("", "Huge")
        D.expect(success).toBe(false)
        D.expect(errorMessage).toBe("Unknown font size 'Huge'")
    end)
end)
