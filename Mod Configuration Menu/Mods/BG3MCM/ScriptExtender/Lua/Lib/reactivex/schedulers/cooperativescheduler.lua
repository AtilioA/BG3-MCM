---@module "util"
local util = Ext.Require("Lib/reactivex/util.lua")
---@module "subscription"
local Subscription = Ext.Require("Lib/reactivex/subscription.lua")

--- @class SchedulerTask
--- @field thread thread
--- @field due number

--- Manages Observables using coroutines and a virtual clock that must be updated manually.
--- @class CooperativeScheduler
--- @field tasks SchedulerTask[]
--- @field _tasksPendingRemoval table<thread, boolean>
--- @field _updating boolean
local CooperativeScheduler = {}
CooperativeScheduler.__index = CooperativeScheduler
CooperativeScheduler.__tostring = util.Constant('CooperativeScheduler')

--- Creates a new CooperativeScheduler.
--- @param currentTime number? [or 0] - A time to start the scheduler at.
--- @return CooperativeScheduler
function CooperativeScheduler.Create(currentTime)
    local self = {
        tasks = {},
        currentTime = currentTime or 0,
        _tasksPendingRemoval = {},
        _updating = false,
    }

    return setmetatable(self, CooperativeScheduler)
end

--- Schedules a function to be run after an optional delay.  Returns a subscription that will stop the action from running.
--- @param action function - The function to execute. Will be converted into a coroutine. The coroutine may yield execution back to the scheduler with an optional number, which will put it to sleep for a time period.
--- @param delay number? [or 0]- Delay execution of the action by a virtual time period.
--- @return Subscription
function CooperativeScheduler:Schedule(action, delay)
    local task = {
        thread = coroutine.create(action),
        due = self.currentTime + (delay or 0)
    } --[[@as SchedulerTask]]

    table.insert(self.tasks, task)

    return Subscription.Create(function()
        return self:Unschedule(task)
    end)
end

---@param task SchedulerTask
function CooperativeScheduler:Unschedule(task)
    for i = 1, #self.tasks do
        if self.tasks[i] == task then
            self:_safeRemoveTaskByIndex(i)
            return
        end
    end
end

--- Triggers an update of the CooperativeScheduler. The clock will be advanced and the scheduler will run any coroutines that are due to be run.
--- @param delta number [or 0] - An amount of time to advance the clock by. It is common to pass in the time in seconds or milliseconds elapsed since this function was last called.
function CooperativeScheduler:Update(delta)
    local throwError, errorMsg = false, nil

    self._updating = true
    self.currentTime = self.currentTime + (delta or 0)

    -- This logic has been splitted to two phases in order to avoid table.remove()
    -- collisions between update() and unschedule().
    -- Separate "staging area" has been introduced, which basically consists of
    -- two additional private tables to temporaily keep track of unscheduled
    -- and dead tasks.

    -- Phase 1 - Execute due tasks
    for i, task in ipairs(self.tasks) do
        if not self._tasksPendingRemoval[task] then
            if self.currentTime >= task.due then
                local success, delay = coroutine.resume(task.thread)

                if coroutine.status(task.thread) == 'dead' then
                    self:_safeRemoveTaskByIndex(i)
                else
                    task.due = math.max(task.due + (delay or 0), self.currentTime)
                end

                if not success then
                    throwError = true
                    errorMsg = delay
                end
            end
        end
    end

    self._updating = false

    -- Phase 2 - Commit changes to the tasks queue and clean staging area
    self:_commitPendingRemovals()

    if throwError then
        error(errorMsg)
    end
end

--- Returns whether or not the CooperativeScheduler's queue is empty.
---@return boolean
function CooperativeScheduler:IsEmpty()
    return #self.tasks == 0
end

---@private
---@param i number
function CooperativeScheduler:_safeRemoveTaskByIndex(i)
    if self._updating then
        self._tasksPendingRemoval[self.tasks[i]] = true
    else
        table.remove(self.tasks, i)
    end
end

---@private
function CooperativeScheduler:_commitPendingRemovals()
    for i = #self.tasks, 1, -1 do
        if self._tasksPendingRemoval[self.tasks[i]] then
            self._tasksPendingRemoval[self.tasks[i]] = nil
            table.remove(self.tasks, i)
        end
    end
end

return CooperativeScheduler
