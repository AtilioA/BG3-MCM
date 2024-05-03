---@class HelperMCMCommands
MCMCommands = _Class:Create("HelperMCMCommands")

--- Registers a console command to run MCM tests.
Ext.RegisterConsoleCommand("mcm_test", function()
    TestSuite.RunTests()
end)
