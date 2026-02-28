---@class HelperMCMCommands
MCMCommands = _Class:Create("HelperMCMCommands")

---@param args any[]
---@return string[]
local function ParseTestNames(args)
    local testNames = {}

    for _, arg in ipairs(args or {}) do
        if type(arg) == "string" then
            local testName = string.match(arg, "^%s*(.-)%s*$")
            if testName ~= "" then
                table.insert(testNames, testName)
            end
        end
    end

    if #testNames > 0 and string.lower(testNames[1]) == "mcm_test" then
        table.remove(testNames, 1)
    end

    return testNames
end

--- Registers a console command to run all MCM tests or a selected subset.
--- Usage:
---   !mcm_test
---   !mcm_test TestName
---   !mcm_test TestNameA TestNameB
Ext.RegisterConsoleCommand("mcm_test", function(...)
    local testNames = ParseTestNames({ ... })
    if #testNames == 0 then
        TestSuite.RunTests()
        return
    end

    TestSuite.RunTestsByNames(testNames)
end)
