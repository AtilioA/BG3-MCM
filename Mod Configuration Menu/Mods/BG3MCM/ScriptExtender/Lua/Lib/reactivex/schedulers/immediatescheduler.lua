---@module "util"
local util = Ext.Require("Lib/reactivex/util.lua")

--- Schedules Observables by running all operations immediately.
--- @class ImmediateScheduler
local ImmediateScheduler = {}
ImmediateScheduler.__index = ImmediateScheduler
ImmediateScheduler.__tostring = util.Constant('ImmediateScheduler')

--- Creates a new ImmediateScheduler
--- @return ImmediateScheduler
function ImmediateScheduler.Create()
    return setmetatable({}, ImmediateScheduler)
end

--- Schedules a function to be run on the scheduler. It is executed immediately.
--- @param action function - The function to execute.
function ImmediateScheduler:Schedule(action)
    action()
end

return ImmediateScheduler
