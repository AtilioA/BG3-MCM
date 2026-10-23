D.describe("InternalAPIGuard", { tags = { "internal-api-guard", "unit" } }, function()
    D.test("PreservesGlobalTables", function()
        D.expect(rawget(Mods, "BG3MCM")).toBe(_G)
    end)

    D.test("ReturnsTheRealInternalAPI", function()
        D.expect(type(MCMAPI)).toBe("table")
        D.expect(rawget(Mods.BG3MCM, "MCMAPI")).toBe(nil)
        D.expect(Mods.BG3MCM.MCMAPI).toBe(MCMAPI)

        if Ext.IsClient() then
            D.expect(type(IMGUIAPI)).toBe("table")
            D.expect(Mods.BG3MCM.IMGUIAPI).toBe(IMGUIAPI)
        end
    end)

    D.test("LeavesPublicAPIFieldsUnchanged", function()
        local rawPublicGet = rawget(Mods.BG3MCM, "Get")
        D.expect(type(rawPublicGet)).toBe("function")
        D.expect(Mods.BG3MCM.Get).toBe(rawPublicGet)

        local rawStore = rawget(Mods.BG3MCM, "Store")
        D.expect(type(rawStore)).toBe("table")
        D.expect(Mods.BG3MCM.Store).toBe(rawStore)
        D.expect(type(rawStore.Set)).toBe("function")
    end)
end)
