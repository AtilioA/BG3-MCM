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
    local visibilityFixture

    D.afterEach(function()
        if not visibilityFixture then return end

        local modElements = VisibilityManager.registered[visibilityFixture.modUUID]
        if modElements then
            modElements[visibilityFixture.widget] = nil
            if not visibilityFixture.hadModElements and next(modElements) == nil then
                VisibilityManager.registered[visibilityFixture.modUUID] = nil
            end
        end
        visibilityFixture = nil
    end)

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
        D.expect(evaluateSingleCondition(modUUID, ">", 10)).toBe(false)
        D.expect(evaluateSingleCondition(modUUID, ">", 11)).toBe(false)
        D.expect(evaluateSingleCondition(modUUID, "<", 20)).toBe(true)
        D.expect(evaluateSingleCondition(modUUID, "<", 10)).toBe(false)
        D.expect(evaluateSingleCondition(modUUID, "<", 9)).toBe(false)
        D.expect(evaluateSingleCondition(modUUID, ">=", 10)).toBe(true)
        D.expect(evaluateSingleCondition(modUUID, ">=", 11)).toBe(false)
        D.expect(evaluateSingleCondition(modUUID, "<=", 10)).toBe(true)
        D.expect(evaluateSingleCondition(modUUID, "<=", 9)).toBe(false)
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

        local allFalse = VisibilityManager.evaluateGroup(modUUID, {
            LogicalOperator = "or",
            Conditions = {
                { SettingId = "test-setting", Operator = ">", ExpectedValue = 100 },
                { SettingId = "test-setting", Operator = "<", ExpectedValue = 0 },
            }
        })
        D.expect(allFalse).toBe(false)
    end)

    D.test("logical AND requires every condition to pass", function(ctx)
        local modUUID = ModuleUUID
        ctx.stub(MCMRendering, "GetClientStateValue", function(_, _)
            return 10
        end)

        local mixed = VisibilityManager.evaluateGroup(modUUID, {
            LogicalOperator = "and",
            Conditions = {
                { SettingId = "test-setting", Operator = ">", ExpectedValue = 5 },
                { SettingId = "test-setting", Operator = "<", ExpectedValue = 5 },
            }
        })
        D.expect(mixed).toBe(false)
    end)

    D.test("updates a mod widget after its saved setting is deferred", function(ctx)
        local modUUID = ModuleUUID
        local otherModUUID = "00000000-0000-0000-0000-000000000099"
        local settingId = "__visibility_manager_test_setting__"
        local values = { [modUUID] = false, [otherModUUID] = false }
        local deferred = {}
        local modElements = VisibilityManager.registered[modUUID]
        local widget = { Visible = nil }
        visibilityFixture = {
            modUUID = modUUID,
            widget = widget,
            hadModElements = modElements ~= nil,
        }

        ctx.stub(MCMRendering, "GetClientStateValue", function(_, requestedSettingId, requestedModUUID)
            if requestedSettingId ~= settingId then return nil end
            return values[requestedModUUID]
        end)
        ctx.stub(VCTimer, "OnTicks", function(_, ticks, callback)
            D.expect(ticks).toBe(1)
            table.insert(deferred, callback)
        end)

        VisibilityManager.registerCondition(modUUID, widget, {
            LogicalOperator = "and",
            Conditions = {
                { SettingId = settingId, Operator = "==", ExpectedValue = true },
            }
        })
        D.expect(widget.Visible).toBe(false)

        local settingSaved = Ext.ModEvents["BG3MCM"][EventChannels.MCM_INTERNAL_SETTING_SAVED]
        values[modUUID] = true
        settingSaved:Throw({ modUUID = modUUID, settingId = settingId, value = true })
        D.expect(widget.Visible).toBe(false)
        local initialUpdate = table.remove(deferred, 1)
        D.expect(initialUpdate).Not.toBeNil()
        initialUpdate()
        D.expect(widget.Visible).toBe(true)

        values[modUUID] = false
        settingSaved:Throw({ modUUID = otherModUUID, settingId = settingId, value = false })
        D.expect(widget.Visible).toBe(true)
        local otherModUpdate = table.remove(deferred, 1)
        D.expect(otherModUpdate).Not.toBeNil()
        otherModUpdate()
        D.expect(widget.Visible).toBe(true)

        settingSaved:Throw({ modUUID = modUUID, settingId = settingId, value = false })
        D.expect(widget.Visible).toBe(true)
        local finalUpdate = table.remove(deferred, 1)
        D.expect(finalUpdate).Not.toBeNil()
        finalUpdate()
        D.expect(widget.Visible).toBe(false)
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
