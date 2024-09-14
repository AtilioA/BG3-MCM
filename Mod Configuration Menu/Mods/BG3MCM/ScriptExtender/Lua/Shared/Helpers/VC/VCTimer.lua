---@class HelperVCTimer: nil
---@field RegisteredObjectTimers table<string, table<Guid, boolean>>
VCTimer = _Class:Create("HelperTimer", nil, {
    RegisteredObjectTimers = {}
})


---Ext.OnNextTick, but variable ticks
---@param ticks integer
---@param fn function
function VCTimer:OnTicks(ticks, fn)
    local ticksPassed = 0
    local eventID
    eventID = Ext.Events.Tick:Subscribe(function()
        ticksPassed = ticksPassed + 1
        if ticksPassed >= ticks then
            fn()
            Ext.Events.Tick:Unsubscribe(eventID)
        end
    end)
end

--- Due to being thrown on-tick, the callback may be performed up to a tick's worth of time after the time is completed, e.g.:
--- Register callback with 50ms delay.
--- Tick 1: 33 ms
--- Tick 2: 66 ms --> callback is performed.
---@param time integer milliseconds
---@param fn function
function VCTimer:OnTime(time, fn)
    local startTime = Ext.Utils.MonotonicTime()
    local eventID
    eventID = Ext.Events.Tick:Subscribe(function()
        if Ext.Utils.MonotonicTime() - startTime >= time then
            fn()
            Ext.Events.Tick:Unsubscribe(eventID)
        end
    end)
end

--- Due to being thrown on-tick, the callback may be performed up to a tick's worth of time after the time is completed, e.g.:
--- Register callback with 50ms delay.
--- Tick 1: 33 ms
--- Tick 2: 66 ms --> callback is performed.
---@param ticks integer
---@param time integer milliseconds
---@param fn function
---@param ticksOrTime? boolean
function VCTimer:OnTicksAndTime(ticks, time, fn, ticksOrTime)
    local startTime = Ext.Utils.MonotonicTime()
    local ticksPassed = 0
    local eventID
    if ticksOrTime then
        eventID = Ext.Events.Tick:Subscribe(function()
            ticksPassed = ticksPassed + 1
            if (Ext.Utils.MonotonicTime() - startTime >= time) or (ticksPassed >= ticks) then
                fn()
                Ext.Events.Tick:Unsubscribe(eventID)
            end
        end)
    else
        eventID = Ext.Events.Tick:Subscribe(function()
            ticksPassed = ticksPassed + 1
            if (Ext.Utils.MonotonicTime() - startTime >= time) and (ticksPassed >= ticks) then
                fn()
                Ext.Events.Tick:Unsubscribe(eventID)
            end
        end)
    end
end

--- Calls the callback with an intervalInMs and stops calling the callback when the totalTimeInMs is reached.
--- @param callback function The callback to call.
--- @param intervalInMs integer The interval to wait before calling the callback again.
--- @param totalTimeInMs integer The total time to call the callback.
function VCTimer:CallWithInterval(callback, intervalInMs, totalTimeInMs)
    if totalTimeInMs <= 0 then
        return
    end

    local elapsedTime = 0

    local function invokeCallback()
        if elapsedTime >= totalTimeInMs then
            return
        end

        local stop = callback()
        if stop ~= nil and stop ~= false then
            return
        end

        elapsedTime = elapsedTime + intervalInMs
        if elapsedTime < totalTimeInMs then
            Ext.Timer.WaitFor(intervalInMs, invokeCallback)
        end
    end

    if intervalInMs > totalTimeInMs then
        intervalInMs = totalTimeInMs
    end

    invokeCallback()
end

--- Repeatedly calls the main callback at specified intervals until the condition callback returns true.
--- @param mainCallback function The primary function to execute.
--- @param intervalMs integer The time intervalInMs in milliseconds between each call of the main callback.
--- @param conditionCallback function A function that returns true to stop further execution of the main callback.
function VCTimer:ExecuteWithIntervalUntilCondition(mainCallback, intervalMs, conditionCallback)
    local function attemptCallbackExecution()
        if conditionCallback() then
            return
        end

        if mainCallback() then
            return
        end

        Ext.Timer.WaitFor(intervalMs, attemptCallbackExecution)
    end

    attemptCallbackExecution()
end
