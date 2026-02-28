TestSuite.RegisterTests("VisibilityManager", {
    "TestVisibilityRelationalOperatorsHandleNonNumericCurrentValue",
    "TestVisibilityRelationalOperatorsHandleNonNumericExpectedValue",
    "TestVisibilityRelationalOperatorsWorkForNumericValues",
})

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

function TestVisibilityRelationalOperatorsHandleNonNumericCurrentValue()
    TestSuite.AssertNotNil(VisibilityManager)

    local operators = { ">", "<", ">=", "<=" }
    local modUUID = TestConstants.ModuleUUIDs[1]

    withVisibilityMocks(function(_, _)
        return "not-a-number"
    end, function()
        for _, operator in ipairs(operators) do
            local result = evaluateSingleCondition(modUUID, operator, "10")
            TestSuite.AssertFalse(result, "Expected false for operator " .. operator .. " with non-numeric current value")
        end
    end)
end

function TestVisibilityRelationalOperatorsHandleNonNumericExpectedValue()
    TestSuite.AssertNotNil(VisibilityManager)

    local operators = { ">", "<", ">=", "<=" }
    local modUUID = TestConstants.ModuleUUIDs[1]

    withVisibilityMocks(function(_, _)
        return 10
    end, function()
        for _, operator in ipairs(operators) do
            local stringResult = evaluateSingleCondition(modUUID, operator, "not-a-number")
            TestSuite.AssertFalse(stringResult,
                "Expected false for operator " .. operator .. " with non-numeric string expected value")

            local boolResult = evaluateSingleCondition(modUUID, operator, true)
            TestSuite.AssertFalse(boolResult,
                "Expected false for operator " .. operator .. " with boolean expected value")
        end
    end)
end

function TestVisibilityRelationalOperatorsWorkForNumericValues()
    TestSuite.AssertNotNil(VisibilityManager)

    local modUUID = TestConstants.ModuleUUIDs[1]

    withVisibilityMocks(function(_, _)
        return 10
    end, function()
        TestSuite.AssertTrue(evaluateSingleCondition(modUUID, ">", 5))
        TestSuite.AssertTrue(evaluateSingleCondition(modUUID, "<", 20))
        TestSuite.AssertTrue(evaluateSingleCondition(modUUID, ">=", 10))
        TestSuite.AssertTrue(evaluateSingleCondition(modUUID, "<=", 10))
    end)
end
