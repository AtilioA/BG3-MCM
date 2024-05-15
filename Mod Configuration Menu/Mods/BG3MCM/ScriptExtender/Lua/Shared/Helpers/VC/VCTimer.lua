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
