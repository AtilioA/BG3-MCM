local function evaluateSingleCondition(modUUID, operator, expectedValue)
    return VisibilityManager.evaluateGroup(modUUID, {
        LogicalOperator = "and",
        Conditions = {
            {
                SettingId = "test-setting",
                Operator = operator,
                ExpectedValue = expectedValue,
            }
        }
    })
end

D.describe("VisibilityManager", { tags = { "visibility", "unit" } }, function()
    D.test("TestVisibilityRelationalOperatorsHandleNonNumericCurrentValue", function(ctx)
        local operators = { ">", "<", ">=", "<=" }
        local modUUID = TestConstants.ModuleUUIDs[1]

        local originalGetMod = Ext.Mod.GetMod
        Ext.Mod.GetMod = function(_)
            return { Info = { Name = "Visibility Test Mod", Author = "Visibility Test Author" } }
        end
        ctx.stub(MCMRendering, "GetClientStateValue", function(_, _)
            return "not-a-number"
        end)

        for _, operator in ipairs(operators) do
            local result = evaluateSingleCondition(modUUID, operator, "10")
            D.expect(result).toBeFalsy()
        end

        Ext.Mod.GetMod = originalGetMod
    end)

    D.test("TestVisibilityRelationalOperatorsHandleNonNumericExpectedValue", function(ctx)
        local operators = { ">", "<", ">=", "<=" }
        local modUUID = TestConstants.ModuleUUIDs[1]

        local originalGetMod = Ext.Mod.GetMod
        Ext.Mod.GetMod = function(_)
            return { Info = { Name = "Visibility Test Mod", Author = "Visibility Test Author" } }
        end
        ctx.stub(MCMRendering, "GetClientStateValue", function(_, _)
            return 10
        end)

        for _, operator in ipairs(operators) do
            local stringResult = evaluateSingleCondition(modUUID, operator, "not-a-number")
            D.expect(stringResult).toBeFalsy()

            local boolResult = evaluateSingleCondition(modUUID, operator, true)
            D.expect(boolResult).toBeFalsy()
        end

        Ext.Mod.GetMod = originalGetMod
    end)

    D.test("TestVisibilityRelationalOperatorsWorkForNumericValues", function(ctx)
        local modUUID = TestConstants.ModuleUUIDs[1]

        local originalGetMod = Ext.Mod.GetMod
        Ext.Mod.GetMod = function(_)
            return { Info = { Name = "Visibility Test Mod", Author = "Visibility Test Author" } }
        end
        ctx.stub(MCMRendering, "GetClientStateValue", function(_, _)
            return 10
        end)

        D.expect(evaluateSingleCondition(modUUID, ">", 5)).toBeTruthy()
        D.expect(evaluateSingleCondition(modUUID, "<", 20)).toBeTruthy()
        D.expect(evaluateSingleCondition(modUUID, ">=", 10)).toBeTruthy()
        D.expect(evaluateSingleCondition(modUUID, "<=", 10)).toBeTruthy()

        Ext.Mod.GetMod = originalGetMod
    end)

    D.test("TestVisibilityLogicalOrOperator", function(ctx)
        local modUUID = TestConstants.ModuleUUIDs[1]

        local originalGetMod = Ext.Mod.GetMod
        Ext.Mod.GetMod = function(_)
            return { Info = { Name = "Visibility Test Mod", Author = "Visibility Test Author" } }
        end
        ctx.stub(MCMRendering, "GetClientStateValue", function(_, _)
            return 10
        end)

        local result = VisibilityManager.evaluateGroup(modUUID, {
            LogicalOperator = "or",
            Conditions = {
                { SettingId = "test-setting", Operator = ">", ExpectedValue = 100 },
                { SettingId = "test-setting", Operator = "<", ExpectedValue = 20 },
            }
        })
        D.expect(result).toBeTruthy()

        Ext.Mod.GetMod = originalGetMod
    end)

    -- D.test("TestVisibilityEmptyConditionsGroup", function(ctx)
    --     local modUUID = TestConstants.ModuleUUIDs[1]

    --     local originalGetMod = Ext.Mod.GetMod
    --     Ext.Mod.GetMod = function(_)
    --         return { Info = { Name = "Visibility Test Mod", Author = "Visibility Test Author" } }
    --     end
    --     ctx.stub(MCMRendering, "GetClientStateValue", function(_, _)
    --         return 10
    --     end)

    --     local result = VisibilityManager.evaluateGroup(modUUID, {
    --         LogicalOperator = "and",
    --         Conditions = {}
    --     })
    --     D.expect(result).toBeFalsy()

    --     Ext.Mod.GetMod = originalGetMod
    -- end)
end)
