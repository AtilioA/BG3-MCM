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
        local modUUID = ModuleUUID

        ctx.stub(MCMRendering, "GetClientStateValue", function(_, _)
            return "not-a-number"
        end)

        for _, operator in ipairs(operators) do
            local result = evaluateSingleCondition(modUUID, operator, "10")
            D.expect(result).toBe(false)
        end
    end)

    D.test("TestVisibilityRelationalOperatorsHandleNonNumericExpectedValue", function(ctx)
        local operators = { ">", "<", ">=", "<=" }
        local modUUID = ModuleUUID

        ctx.stub(MCMRendering, "GetClientStateValue", function(_, _)
            return 10
        end)

        for _, operator in ipairs(operators) do
            local stringResult = evaluateSingleCondition(modUUID, operator, "not-a-number")
            D.expect(stringResult).toBe(false)

            local boolResult = evaluateSingleCondition(modUUID, operator, true)
            D.expect(boolResult).toBe(false)
        end
    end)

    D.test("TestVisibilityRelationalOperatorsWorkForNumericValues", function(ctx)
        local modUUID = ModuleUUID

        ctx.stub(MCMRendering, "GetClientStateValue", function(_, _)
            return 10
        end)

        D.expect(evaluateSingleCondition(modUUID, ">", 5)).toBe(true)
        D.expect(evaluateSingleCondition(modUUID, "<", 20)).toBe(true)
        D.expect(evaluateSingleCondition(modUUID, ">=", 10)).toBe(true)
        D.expect(evaluateSingleCondition(modUUID, "<=", 10)).toBe(true)
    end)

    D.test("TestVisibilityLogicalOrOperator", function(ctx)
        local modUUID = ModuleUUID
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
        D.expect(result).toBe(true)
    end)

    D.test("TestVisibilityEmptyConditionsGroupIsVisible", function()
        local modUUID = ModuleUUID

        local result = VisibilityManager.evaluateGroup(modUUID, {
            LogicalOperator = "and",
            Conditions = {}
        })
        D.expect(result).toBe(true)
    end)
end)
