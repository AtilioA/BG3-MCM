D.describe("InternalAPIGuard", { tags = { "internal-api-guard", "unit" } }, function()
    D.test("PreservesGlobalTables", function()
        D.expect(rawget(Mods, "BG3MCM")).toBe(_G)
    end)

    D.test("ReturnsTheRealInternalAPI", function()
        D.expect(rawget(Mods.BG3MCM, "MCMAPI")).toBe(nil)
        D.expect(Mods.BG3MCM.MCMAPI).toBe(MCMAPI)

        if Ext.IsClient() then
            D.expect(Mods.BG3MCM.IMGUIAPI).toBe(IMGUIAPI)
        end
    end)

    D.test("LeavesPublicAPIFieldsUnchanged", function()
        D.expect(rawget(Mods.BG3MCM, "Get")).toBeTruthy()
        D.expect(Mods.BG3MCM.Get).toBe(rawget(Mods.BG3MCM, "Get"))
    end)
end)
