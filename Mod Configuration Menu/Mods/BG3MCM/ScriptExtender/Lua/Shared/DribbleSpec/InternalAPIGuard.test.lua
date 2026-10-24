D.describe("InternalAPIGuard", { tags = { "internal-api-guard", "unit" } }, function()
    D.test("PreservesGlobalTables", function()
        D.expect(rawget(Mods, "BG3MCM")).toBe(_G)
    end)

    D.test("ReturnsTheRealInternalAPI", function()
        D.expect(type(MCMAPI)).toBe("table")
        D.expect(Mods.BG3MCM.MCMAPI).toBe(MCMAPI)

        if Ext.IsClient() then
            D.expect(type(IMGUIAPI)).toBe("table")
            D.expect(Mods.BG3MCM.IMGUIAPI).toBe(IMGUIAPI)
        end
    end)

    D.test("PublicSettingsFacadeCanReadMCMSettings", function()
        D.expect(type(MCM.Get("debug_level"))).toBe("number")
    end)
end)
