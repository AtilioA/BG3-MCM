D.describe("global IMGUI font", { tags = { "font", "client" } }, function()
    D.test("rejects an unknown typeface", function()
        local success, errorMessage = Font.ApplyGlobalFont("NotARealTypeface", "Default")
        D.expect(success).toBe(false)
        D.expect(errorMessage).toBe("Unknown font typeface 'NotARealTypeface'")
    end)

    D.test("rejects a size that is not a positive number", function()
        for _, size in ipairs({ "Large", 0 }) do
            local success, errorMessage = Font.ApplyGlobalFont("", size)
            D.expect(success).toBe(false)
            D.expect(errorMessage).toBe(string.format("Invalid font size '%s'", tostring(size)))
        end
    end)
end)
