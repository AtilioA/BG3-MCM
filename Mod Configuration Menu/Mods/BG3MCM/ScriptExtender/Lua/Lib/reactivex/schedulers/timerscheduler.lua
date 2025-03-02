---@module "subscription"
local Subscription = Ext.Require("Lib/reactivex/subscription.lua")
---@module "util"
local util = Ext.Require("Lib/reactivex/util.lua")

--- A scheduler that uses Ext.Timer to schedule events on delay, optionally every X milliseconds
--- @class TimerScheduler
local TimerScheduler = {}
TimerScheduler.__index = TimerScheduler
TimerScheduler.__tostring = util.Constant('TimeoutScheduler')

--- Creates a new TimeoutScheduler.
--- @return TimerScheduler
function TimerScheduler.Create()
    return setmetatable({}, TimerScheduler)
end

--- Schedules an action to run at a future point in time.
--- @param action function - The action to run.
--- @param delay number? 0 - The delay, in milliseconds.
--- @param repeatEvery number? - Optional repeat frequency
--- @return Subscription
function TimerScheduler:Schedule(action, delay, repeatEvery)
    local handle
    handle = Ext.Timer.WaitFor(delay or 0, action, repeatEvery)
    return Subscription.Create(function()
        Ext.Timer.Cancel(handle)
    end)
end

return TimerScheduler
