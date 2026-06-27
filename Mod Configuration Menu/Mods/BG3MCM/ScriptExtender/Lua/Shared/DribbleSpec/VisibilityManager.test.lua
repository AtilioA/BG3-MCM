local function withVisibilityMocks(getValueFn, testFn)
    local originalGetMod = Ext.Mod.GetMod
    local originalRendering = MCMRendering

    Ext.Mod.GetMod = function(_)
        return {
            Info = {
                Name = "Visibility Test Mod",
                Author = "Visibility Test Author",
            }
        }
    end

    MCMRendering = {
        GetClientStateValue = function(settingId, modUUID)
            return getValueFn(settingId, modUUID)
        end
    }

    local ok, err = xpcall(testFn, debug.traceback)

    Ext.Mod.GetMod = originalGetMod
    MCMRendering = originalRendering

    if not ok then
        error(err)
    end
end

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
    D.test("TestVisibilityRelationalOperatorsHandleNonNumericCurrentValue", function()
        D.expect(VisibilityManager).Not.toBeNil()

        local operators = { ">", "<", ">=", "<=" }
        local modUUID = TestConstants.ModuleUUIDs[1]

        withVisibilityMocks(function(_, _)
            return "not-a-number"
        end, function()
            for _, operator in ipairs(operators) do
                local result = evaluateSingleCondition(modUUID, operator, "10")
                D.expect(result).toBeFalsy()
            end
        end)
    end)

    D.test("TestVisibilityRelationalOperatorsHandleNonNumericExpectedValue", function()
        D.expect(VisibilityManager).Not.toBeNil()

        local operators = { ">", "<", ">=", "<=" }
        local modUUID = TestConstants.ModuleUUIDs[1]

        withVisibilityMocks(function(_, _)
            return 10
        end, function()
            for _, operator in ipairs(operators) do
                local stringResult = evaluateSingleCondition(modUUID, operator, "not-a-number")
                D.expect(stringResult).toBeFalsy()

                local boolResult = evaluateSingleCondition(modUUID, operator, true)
                D.expect(boolResult).toBeFalsy()
            end
        end)
    end)

    D.test("TestVisibilityRelationalOperatorsWorkForNumericValues", function()
        D.expect(VisibilityManager).Not.toBeNil()

        local modUUID = TestConstants.ModuleUUIDs[1]

        withVisibilityMocks(function(_, _)
            return 10
        end, function()
            D.expect(evaluateSingleCondition(modUUID, ">", 5)).toBeTruthy()
            D.expect(evaluateSingleCondition(modUUID, "<", 20)).toBeTruthy()
            D.expect(evaluateSingleCondition(modUUID, ">=", 10)).toBeTruthy()
            D.expect(evaluateSingleCondition(modUUID, "<=", 10)).toBeTruthy()
        end)
    end)
end)
