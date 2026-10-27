D.describe("InternalAPIGuard", { tags = { "internal-api-guard", "unit" } }, function()
    local originalMCMAPIMods

    D.beforeEach(function()
        originalMCMAPIMods = MCMAPI.mods
    end)

    D.afterEach(function()
        MCMAPI.mods = originalMCMAPIMods
    end)

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

    D.test("PublicSettingsFacadeReadsFixtureValuesWithoutAnInternalAPIWarning", function(ctx)
        local warnings = {}
        ctx.stub(Mods.BG3MCM, "MCMDeprecation", function(...)
            table.insert(warnings, { ... })
        end)
        MCMAPI.mods = {
            [ModuleUUID] = { settingsValues = { guard_fixture_value = 17 } },
        }
        local value = MCM.Get("guard_fixture_value")

        D.expect(value).toBe(17)
        D.expect(warnings).toEqual({})
    end)
end)
