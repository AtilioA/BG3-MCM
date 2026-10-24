D.describe("global IMGUI typeface", { tags = { "font", "client" } }, function()

    D.test("rejects an unknown typeface", function()
        local success, errorMessage = Font.ApplyGlobalTypeface("NotARealTypeface")
        D.expect(success).toBe(false)
        D.expect(errorMessage).toBe("Unknown font typeface 'NotARealTypeface'")
    end)
end)
