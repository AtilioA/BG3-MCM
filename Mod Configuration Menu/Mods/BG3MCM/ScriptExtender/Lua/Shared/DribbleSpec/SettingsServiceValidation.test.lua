-- Covers validation outcomes of SettingsService Get, GetAllForStorageType and Set through a fake storage adapter.
local SettingsService = Ext.Require("Shared/DynamicSettings/Services/SettingsService.lua")
local AdapterFactory = Ext.Require("Shared/DynamicSettings/Factories/AdapterFactory.lua")

D.describe("SettingsService validation", { tags = { "store", "unit", "settings-validation" } }, function()
    local MOD = "dribblespec-validation-mod"
    local STORAGE = "fake"
    local previousSchema, previousVarToStorageType
    local state

    D.beforeEach(function(ctx)
        previousSchema = SettingsService.schema
        previousVarToStorageType = SettingsService.varToStorageType
        SettingsService.schema = {}
        SettingsService.varToStorageType = {}

        state = { values = {}, writes = {}, warnings = {}, events = {}, refuseWrites = false }
        local adapter = {
            EnsureRegistered = function() return true end,
            OwnsDefaults = function() return false end,
            GetValue = function(_, varName) return state.values[varName] end,
            SetValue = function(_, varName, value)
                table.insert(state.writes, { varName = varName, value = value })
                if state.refuseWrites then
                    return false
                end
                state.values[varName] = value
            end,
        }
        ctx.stub(AdapterFactory, "GetAdapter", function() return adapter end)
        ctx.stub(Mods.BG3MCM, "MCMWarn", function(_, fmt, ...)
            table.insert(state.warnings, string.format(fmt, ...))
        end)
        ctx.stub(ModEventManager, "Emit", function(_, name, data, bothContexts)
            table.insert(state.events, { name = name, data = data, bothContexts = bothContexts })
        end)
    end)

    D.afterEach(function()
        SettingsService.schema = previousSchema
        SettingsService.varToStorageType = previousVarToStorageType
    end)

    --- Register a variable with a stored value.
    ---@param varName string
    ---@param definition table
    ---@param stored any
    local function register(varName, definition, stored)
        D.expect(SettingsService.Register(MOD, varName, STORAGE, definition)).toBe(true)
        state.values[varName] = stored
    end

    --- Warning text that Get logs when it rejects `v` and reverts it to `default`.
    ---@param problem string
    ---@param default any
    ---@return string
    local function getWarning(problem, default)
        return string.format(
            "Get: Validation/Coercion failed for %s (v) for type %s: %s. Reverting setting value to default: %s.",
            MOD, STORAGE, problem, default)
    end

    --- Warning text that Set logs when it rejects a write of `v`.
    ---@param problem string
    ---@param default any
    ---@return string
    local function setWarning(problem, default)
        return string.format("Set: Validation/Coercion failed for %s (v) in %s: %s. Reverting to default: %s.",
            MOD, STORAGE, problem, default)
    end

    --- Expect the exact warning text, with Lua's `file:line:` location before `problem`.
    ---@param warning string
    ---@param formatWarning fun(problem: string, default: any): string
    ---@param problem string
    ---@param default any
    local function expectLocatedWarning(warning, formatWarning, problem, default)
        local before, after = formatWarning("@", default):match("^(.*)@(.*)$")
        D.expect(warning:sub(1, #before)).toBe(before)
        D.expect(warning:sub(-#after)).toBe(after)
        D.expect(warning:sub(#before + 1, -#after - 1):match("^.+:%d+: (.*)$")).toBe(problem)
    end

    D.test("TestStoredFalseAndZeroAreValid", function()
        register("flag", { type = "boolean", default = true }, false)
        register("count", { type = "number", default = 9 }, 0)

        D.expect(SettingsService.Get(MOD, "flag")).toBe(false)
        D.expect(SettingsService.Get(MOD, "count")).toBe(0)
        D.expect(SettingsService.GetAllForStorageType(MOD, STORAGE)).toEqual({ flag = false, count = 0 })
        D.expect(SettingsService.Set(MOD, "flag", false)).toBe(true)
        D.expect(SettingsService.Set(MOD, "count", 0)).toBe(true)
        D.expect(state.warnings).toEqual({})
    end)

    D.test("TestNilSkipsValidatorInGetGetAllAndSet", function()
        local calls = 0
        register("v", { default = "d", validate = function() calls = calls + 1 end }, nil)

        D.expect(SettingsService.Get(MOD, "v")).toBe("d")
        D.expect(SettingsService.GetAllForStorageType(MOD, STORAGE)).toEqual({ v = "d" })
        D.expect(SettingsService.Set(MOD, "v", nil)).toBe(true)

        D.expect(calls).toBe(0)
        D.expect(state.warnings).toEqual({})
    end)

    D.test("TestGetRepairsDeclaredTypeMismatchWithDefault", function()
        register("v", { type = "number", default = 3 }, "text")

        D.expect(SettingsService.Get(MOD, "v")).toBe(3)

        D.expect(#state.warnings).toBe(1)
        expectLocatedWarning(state.warnings[1], getWarning, "Expected number, got string", 3)
        D.expect(state.writes).toEqual({ { varName = "v", value = 3 } })
        D.expect(state.events).toEqual({})
    end)

    D.test("TestGetRepairsWithFalseDefaultAndNilDefault", function()
        register("v", { type = "number", default = false }, "text")
        D.expect(SettingsService.Get(MOD, "v")).toBe(false)
        D.expect(state.values.v).toBe(false)

        register("w", { type = "number" }, "text")
        D.expect(SettingsService.Get(MOD, "w")).toBeNil()
        D.expect(state.values.w).toBeNil()
        D.expect(#state.writes).toBe(2)
    end)

    D.test("TestGetAllOmitsInvalidEntriesAndContinuesWithoutRepairOrDiagnostic", function()
        register("mismatch", { type = "number", default = 1 }, "text")
        register("rejected", { default = 2, validate = function() return false, "no" end }, "x")
        register("throws", { default = 3, validate = function() error("boom") end }, "x")
        register("errorObject", { validate = function() error({}) end }, "x")
        register("notCallable", { validate = "not a function" }, "x")
        register("valid", { type = "string" }, "kept")
        register("absent", { default = "d" }, nil)

        D.expect(SettingsService.GetAllForStorageType(MOD, STORAGE)).toEqual({ valid = "kept", absent = "d" })

        D.expect(state.warnings).toEqual({})
        D.expect(state.writes).toEqual({})
        D.expect(state.values.mismatch).toBe("text")
    end)

    D.test("TestSetRejectionRepairsWithDefaultAndEmitsCorrection", function()
        register("v", { type = "number", default = 5 }, 7)

        D.expect(SettingsService.Set(MOD, "v", "bad")).toBe(false)

        D.expect(#state.warnings).toBe(1)
        expectLocatedWarning(state.warnings[1], setWarning, "Expected number, got string", 5)
        D.expect(state.values.v).toBe(5)
        D.expect(state.events).toEqual({ {
            name = EventChannels.MCM_DYNAMIC_SETTING_SAVED,
            data = { modUUID = MOD, key = "v", storageType = STORAGE, oldValue = "bad", value = 5 },
            bothContexts = true,
        } })
    end)

    D.test("TestSetRejectionWithoutDefaultKeepsValueAndEmitsNothing", function()
        register("v", { type = "number" }, 7)

        D.expect(SettingsService.Set(MOD, "v", "bad")).toBe(false)

        D.expect(state.values.v).toBe(7)
        D.expect(state.writes).toEqual({})
        D.expect(state.events).toEqual({})
    end)

    D.test("TestSetRejectionWithRefusedRepairEmitsNothing", function()
        register("v", { type = "number", default = 5 }, 7)
        state.refuseWrites = true

        D.expect(SettingsService.Set(MOD, "v", "bad")).toBe(false)

        D.expect(state.values.v).toBe(7)
        D.expect(state.writes).toEqual({ { varName = "v", value = 5 } })
        D.expect(state.events).toEqual({})
    end)

    D.test("TestAcceptedSetWithRefusedWriteEmitsNothing", function()
        register("v", { type = "number" }, 7)
        state.refuseWrites = true

        D.expect(SettingsService.Set(MOD, "v", 8)).toBe(false)

        D.expect(state.events).toEqual({})
        D.expect(state.warnings).toEqual({})
    end)

    D.test("TestAcceptedSetEmitsOldAndNewValue", function()
        register("v", { type = "number", validate = function() return true end }, 7)

        D.expect(SettingsService.Set(MOD, "v", 8)).toBe(true)

        D.expect(state.events).toEqual({ {
            name = EventChannels.MCM_DYNAMIC_SETTING_SAVED,
            data = { modUUID = MOD, key = "v", storageType = STORAGE, oldValue = 7, value = 8 },
            bothContexts = true,
        } })
    end)

    local truthyReturns = { zero = 0, emptyString = "", table = {}, trueValue = true }
    for name, truthy in pairs(truthyReturns) do
        D.test("TestTruthyValidatorReturnAccepts_" .. name, function()
            register("v", { default = "d", validate = function() return truthy end }, "x")

            D.expect(SettingsService.Get(MOD, "v")).toBe("x")
            D.expect(SettingsService.GetAllForStorageType(MOD, STORAGE)).toEqual({ v = "x" })
            D.expect(SettingsService.Set(MOD, "v", "y")).toBe(true)
            D.expect(state.warnings).toEqual({})
        end)
    end

    D.test("TestCallableTableValidatorIsCalled", function()
        local validate = setmetatable({}, { __call = function(_, value) return value == "x", "only x" end })
        register("v", { validate = validate }, "x")

        D.expect(SettingsService.Get(MOD, "v")).toBe("x")
        D.expect(SettingsService.Set(MOD, "v", "y")).toBe(false)
        D.expect(state.warnings[1]).toContain("Validation failed: only x")
    end)

    local concatResult = setmetatable({}, { __tostring = function() return "concat result" end })
    local exactRejections = {
        noReturn = { validate = function() end, problem = "Validation failed: unknown error", located = true },
        falseMessage = { validate = function() return false, false end, problem = "Validation failed: unknown error", located = true },
        nilAccepted = { validate = function() return nil, "said nil" end, problem = "Validation failed: said nil", located = true },
        numberMessage = { validate = function() return false, 7 end, problem = "Validation failed: 7", located = true },
        thrownString = { validate = function() error("boom", 0) end, problem = "boom" },
        thrownNil = { validate = function() error(nil) end, problem = "nil" },
        thrownNumber = { validate = function() error(42) end, problem = "42" },
        thrownObject = {
            validate = function() error(setmetatable({}, { __tostring = function() return "thrown object" end })) end,
            problem = "thrown object",
        },
        concatObject = {
            validate = function()
                return false, setmetatable({}, { __concat = function() return concatResult end })
            end,
            problem = "concat result",
        },
        concatNil = {
            validate = function()
                return false, setmetatable({}, { __concat = function() return nil end })
            end,
            problem = "nil",
        },
        concatThrows = {
            validate = function()
                return false, setmetatable({}, { __concat = function() error("concat boom", 0) end })
            end,
            problem = "concat boom",
        },
    }
    for name, case in pairs(exactRejections) do
        D.test("TestValidatorRejectionKeepsProblem_" .. name, function()
            register("v", { default = "d", validate = case.validate }, "x")

            D.expect(SettingsService.GetAllForStorageType(MOD, STORAGE)).toEqual({})
            D.expect(state.writes).toEqual({})
            D.expect(SettingsService.Get(MOD, "v")).toBe("d")
            D.expect(#state.warnings).toBe(1)
            if case.located then
                expectLocatedWarning(state.warnings[1], getWarning, case.problem, "d")
            else
                D.expect(state.warnings[1]).toBe(getWarning(case.problem, "d"))
            end

            state.warnings = {}
            state.events = {}
            D.expect(SettingsService.Set(MOD, "v", "bad")).toBe(false)
            D.expect(#state.warnings).toBe(1)
            if case.located then
                expectLocatedWarning(state.warnings[1], setWarning, case.problem, "d")
            else
                D.expect(state.warnings[1]).toBe(setWarning(case.problem, "d"))
            end
            D.expect(state.events[1].data.oldValue).toBe("bad")
            D.expect(state.events[1].data.value).toBe("d")
        end)
    end

    local runtimeErrors = {
        { name = "NotCallable", validate = "not a function", text = "attempt to call a string value" },
        { name = "TableMessage", validate = function() return false, {} end, text = "attempt to concatenate a table value" },
    }
    for _, case in ipairs(runtimeErrors) do
        D.test("TestValidatorRuntimeErrorRejects_" .. case.name, function()
            register("v", { default = "d", validate = case.validate }, "x")

            D.expect(SettingsService.Get(MOD, "v")).toBe("d")
            D.expect(state.warnings[1]).toContain(case.text)
            D.expect(state.values.v).toBe("d")
        end)
    end

    D.test("TestUnknownDeclaredTypeWarnsThenRunsValidator", function()
        local warningsSeenByValidator
        register("v", {
            type = "integer",
            validate = function()
                warningsSeenByValidator = #state.warnings
                return true
            end,
        }, "x")

        D.expect(SettingsService.Get(MOD, "v")).toBe("x")

        D.expect(warningsSeenByValidator).toBe(1)
        D.expect(state.warnings).toEqual({ "Unknown declared type: integer" })
    end)

    D.test("TestUnknownDeclaredTypeWarningFailureRejectsValue", function()
        local badType = setmetatable({}, { __tostring = function() error("type boom", 0) end })
        local calls = 0
        register("v", { type = badType, default = "d", validate = function() calls = calls + 1 end }, "x")

        D.expect(SettingsService.GetAllForStorageType(MOD, STORAGE)).toEqual({})
        D.expect(SettingsService.Get(MOD, "v")).toBe("d")

        D.expect(calls).toBe(0)
        D.expect(state.warnings).toEqual({ getWarning("type boom", "d") })
    end)

    D.test("TestRejectionLogFailurePropagatesFromGetAndSetBeforeRepair", function()
        local badError = setmetatable({}, { __tostring = function() error("log boom", 0) end })
        register("v", { default = "d", validate = function() error(badError) end }, "x")

        D.expect(SettingsService.GetAllForStorageType(MOD, STORAGE)).toEqual({})

        -- Expects "log boom" from the rejection log's __tostring.
        local getOk, getError = pcall(SettingsService.Get, MOD, "v")
        D.expect(getOk).toBe(false)
        D.expect(getError).toBe("log boom")

        -- Expects "log boom" from the rejection log's __tostring.
        local setOk, setError = pcall(SettingsService.Set, MOD, "v", "bad")
        D.expect(setOk).toBe(false)
        D.expect(setError).toBe("log boom")

        D.expect(state.writes).toEqual({})
        D.expect(state.events).toEqual({})
    end)

    D.test("TestReentrantValidatorKeepsInnerAndOuterOutcomes", function()
        local entered = false
        register("other", {}, 1)
        register("v", {
            default = "d",
            validate = function()
                if not entered then
                    entered = true
                    D.expect(SettingsService.Set(MOD, "other", 2)).toBe(true)
                end
                return false, "rejected after reentry"
            end,
        }, "x")

        D.expect(SettingsService.Get(MOD, "v")).toBe("d")

        D.expect(state.values.other).toBe(2)
        D.expect(state.values.v).toBe("d")
        D.expect(#state.events).toBe(1)
        D.expect(state.events[1].data.key).toBe("other")
        D.expect(#state.warnings).toBe(1)
        expectLocatedWarning(state.warnings[1], getWarning, "Validation failed: rejected after reentry", "d")
    end)

    D.test("TestReentrantValidatorCanReadItsOwnVariable", function()
        local inner
        local entered = false
        register("v", {
            validate = function()
                if not entered then
                    entered = true
                    inner = SettingsService.Get(MOD, "v")
                end
                return true
            end,
        }, "x")

        D.expect(SettingsService.Get(MOD, "v")).toBe("x")
        D.expect(inner).toBe("x")
        D.expect(state.writes).toEqual({})
    end)
end)
