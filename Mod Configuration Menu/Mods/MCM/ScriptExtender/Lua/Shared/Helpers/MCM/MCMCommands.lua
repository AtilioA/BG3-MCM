---@class HelperMCMCommands
MCMCommands = _Class:Create("HelperMCMCommands")

Ext.RegisterConsoleCommand('mcm_reset', function() MCM:ResetCommand() end)
