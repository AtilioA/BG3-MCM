D.describe("global IMGUI typeface", { tags = { "font", "client" } }, function()

    D.test("rejects an unknown typeface", function()
        local success, errorMessage = Font.ApplyGlobalTypeface("NotARealTypeface")
        D.expect(success).toBe(false)
        D.expect(errorMessage).toBe("Unknown font typeface 'NotARealTypeface'")
    end)

    -- Reapplies the active selection, so the engine deduplicates it and the live fonts do not change
    D.test("applies the saved typeface to the built-in fonts", function()
        local success, errorMessage = Font.ApplyGlobalTypeface(MCMClientState:GetMCMTypeface())
        D.expect(errorMessage).toBeNil()
        D.expect(success).toBe(true)
    end)
end)
