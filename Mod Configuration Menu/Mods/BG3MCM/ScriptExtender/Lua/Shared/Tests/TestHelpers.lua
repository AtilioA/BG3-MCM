--[[
    This file contains code adapted from Baldur's Gate 3 Script Extender (BG3SE). The terms of the license for BG3SE are as follows:

    ## “Commons Clause” License Condition v1.0

    The Software is provided to you by the Licensor under the License,
    as defined below, subject to the following condition.

    Without limiting other conditions in the License, the grant of rights
    under the License will not include, and the License does not grant to you,
    the right to Sell the Software.

    For purposes of the foregoing, “Sell” means practicing any or all of the
    rights granted to you under the License to provide to third parties, for a
    fee or other consideration (including without limitation fees for hosting
    or consulting/ support services related to the Software), a product or
    service whose value derives, entirely or substantially, from the functionality
    of the Software. Any license notice or attribution required by the License
    must also include this Commons Clause License Condition notice.


    ## MIT License

    Copyright (c) 2021-2023 Norbyte

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

    ---
    For more information, please refer to https://github.com/Norbyte/bg3se
]]

---@class TestSuite
TestSuite = {}

---A table to store the registered tests.
TestSuite.RegisteredTests = {}

---Registers a set of tests for a given category.
---@param category string The category to register the tests under.
---@param tests table An array of test functions to register.
function TestSuite.RegisterTests(category, tests)
    if TestSuite.RegisteredTests[category] == nil then
        TestSuite.RegisteredTests[category] = {}
    end

    for i, test in pairs(tests) do
        table.insert(TestSuite.RegisteredTests[category], test)
    end
end

---Runs all the registered tests.
function TestSuite.RunTests()
    local totalTests = 0
    local totalPassed = 0
    local totalFailed = 0
    local failedTestNames = {}

    Ext.Utils.Print("--- STARTING TESTS ---")

    for category, tests in pairs(TestSuite.RegisteredTests) do
        local categoryPassed = 0
        local categoryFailed = 0
        Ext.Utils.Print("  -- Category: " .. category)
        for i, test in ipairs(tests) do
            totalTests = totalTests + 1
            local testHasPassed = TestSuite.RunTest(test, _G[test])
            if testHasPassed then
                categoryPassed = categoryPassed + 1
                totalPassed = totalPassed + 1
            else
                categoryFailed = categoryFailed + 1
                totalFailed = totalFailed + 1
                table.insert(failedTestNames, test)
            end
        end

        -- Print the passed and failed test indicators for the category
        local passedTestIndicator = string.rep("\x1b[38;2;21;255;81m■\x1b[0m", categoryPassed)
        if passedTestIndicator == 0 then
            passedTestIndicator = "0"
        end
        local failedTestIndicator = string.rep("\x1b[38;2;255;0;0m■\x1b[0m", categoryFailed)
        if categoryFailed == 0 then
            failedTestIndicator = "0"
        end
        Ext.Utils.Print("  Passed: " .. passedTestIndicator)
        Ext.Utils.Print("  Failed: " .. failedTestIndicator .. "\n")
    end

    Ext.Utils.Print("--- FINISHING TESTS ---")

    local testSuiteSummary = string.format(
        "\x1b[38;2;255;255;255m\x1b[1mTest Suite Summary:\x1b[0m\n" ..
        "  Total Tests:  \x1b[38;2;255;255;255m\x1b[1m%d\x1b[0m\n" ..
        "  Passed Tests: \x1b[38;2;21;255;81m\x1b[1m%d\x1b[0m\n" ..
        "  Failed Tests: \x1b[38;2;255;0;0m\x1b[1m%d%s\x1b[0m",
        totalTests, totalPassed, totalFailed, totalFailed > 0 and " - " .. table.concat(failedTestNames, ", ") or ""
    )
    Ext.Utils.Print(testSuiteSummary)
end

---Asserts that the given expression is true.
---@param expr boolean The expression to assert.
function TestSuite.Assert(expr)
    if not expr then
        error("Assertion failed")
    end
end

---Asserts that the given value is equal to the expected value.
---@param value any The value to compare.
---@param expectation any The expected value.
function TestSuite.AssertEquals(value, expectation)
    local equals
    if type(expectation) == "table" then
        equals = (Ext.Json.Stringify(expectation) == Ext.Json.Stringify(value))
    else
        equals = (expectation == value)
    end

    if not equals then
        error("Expressions not equal: expected " ..
            Ext.Json.Stringify(expectation, false, true) .. " , got " .. Ext.Json.Stringify(value, false, true))
    end
end

---Asserts that the type of the given value matches the expected type.
---@param value any The value to check.
---@param expectation string The expected type.
function TestSuite.AssertType(value, expectation)
    local ty = type(value)
    if ty ~= expectation then
        error("Expressions type not equal: expected " .. expectation .. " , got " .. ty)
    end
end

---Asserts that the given floating-point value is equal to the expected value within a small tolerance.
---@param value number The value to compare.
---@param expectation number The expected value.
function TestSuite.AssertEqualsFloat(value, expectation)
    if math.abs(expectation - value) > 0.00001 then
        error("Expressions not equal: expected " .. expectation .. " , got " .. value)
    end
end

---Asserts that the property of the given value matches the expected value.
---@param k string The property key.
---@param expectation any The expected value.
---@param value any The value to check.
function TestSuite.AssertPropertyEquals(k, expectation, value)
    if Ext.Utils.IsIterable(expectation) then
        if type(value) == "table" then
            TestSuite.AssertEqualsProperties(expectation, value)
        else
            local mt = getmetatable(value)
            if mt == "bg3se::Array" then
                TestSuite.AssertEqualsArray(expectation, value)
            elseif mt == "bg3se::Set" then
                TestSuite.AssertEqualsSet(expectation, value)
            elseif mt == "bg3se::Map" or mt == "bg3se::Object" then
                TestSuite.AssertEqualsProperties(expectation, value)
            else
                error("Don't know how to assert userdata: " .. mt)
            end
        end
        return
    end

    local equals
    if type(expectation) == "number" then
        equals = (math.abs(expectation - value) < 0.00001)
    else
        equals = (expectation == value)
    end

    if not equals then
        if type(expectation) == "number" then
            error("Property value not equal: " .. k .. ": " .. expectation .. " = " .. value)
        else
            error("Property value not equal: " ..
                k ..
                ": " .. Ext.Json.Stringify(expectation, false, true) .. " = " .. Ext.Json.Stringify(value, false, true))
        end
    end
end

---Asserts that the given array matches the expected array.
---@param expectation table The expected array.
---@param value table The array to check.
function TestSuite.AssertEqualsArray(expectation, value)
    if #expectation ~= #value then
        error("Array length not equal: " .. #expectation .. " = " .. #value)
    end

    for k, exp in ipairs(expectation) do
        local val = value[k]
        TestSuite.AssertPropertyEquals(k, exp, val)
    end
end

---Asserts that the given set matches the expected set.
---@param expectation table The expected set.
---@param value table The set to check.
function TestSuite.AssertEqualsSet(expectation, value)
    if #expectation ~= #value then
        error("Set length not equal: " .. #expectation .. " = " .. #value)
    end

    for k, exp in ipairs(expectation) do
        if value[exp] ~= true then
            error("Value not in set: " .. exp)
        end
    end
end

---Asserts that the properties of the given value match the expected properties.
---@param expectation table The expected properties.
---@param value table The value to check.
function TestSuite.AssertEqualsProperties(expectation, value)
    for k, exp in pairs(expectation) do
        local val = value[k]

        TestSuite.AssertPropertyEquals(k, exp, val)
    end
end

---Asserts that the given array contains the specified element.
---@param arr table The array to check.
---@param element any The element to look for.
function TestSuite.AssertContains(arr, element)
    for _, v in pairs(arr) do
        if v == element then
            return
        end
    end

    error("Element not in table: " .. element)
end

---Asserts that the given value is a valid structure.
---@param val any The value to check.
function TestSuite.AssertValid(val)
    if not Ext.Types.Validate(val) then
        error("Structure not valid: " .. val)
    end
end

---Runs a test and prints the result.
---@param name string The name of the test.
---@param fun function The test function to run.
function TestSuite.RunTest(name, fun)
    local result, err = xpcall(fun, debug.traceback)
    if result then
        Ext.Utils.Print(TestSuite.FormatTestOkMessage(name))
        return true
    else
        Ext.Utils.PrintError("■ Test FAILED: " .. name)
        Ext.Utils.PrintError(err .. "\n")
        return false
    end
end

---Formats the test OK message with color.
---@param name string The name of the test.
---@return string - The formatted test OK message.
function TestSuite.FormatTestOkMessage(name)
    return string.format("\x1b[38;2;21;255;81m■ Test OK: %s\x1b[0m\n", name)
end

---Asserts that the given value is nil.
---@param val any The value to check.
function TestSuite.AssertNil(val)
    if val ~= nil then
        local valStr = tostring(val)
        error("Value not nil: " .. (valStr or ""))
    end
end

---Asserts that the given value is not nil.
---@param val any The value to check.
function TestSuite.AssertNotNil(val)
    if val == nil then
        error("Value is nil")
    end
end

---Asserts that the given value is true.
---@param val boolean The value to check.
function TestSuite.AssertTrue(val)
    if val ~= true then
        local valStr = tostring(val)
        error("Value not true: " .. (valStr or ""))
    end
end

---Asserts that the given value is false.
---@param val boolean The value to check.
function TestSuite.AssertFalse(val)
    if val ~= false then
        local valStr = tostring(val)
        error("Value not false: " .. (valStr or ""))
    end
end
