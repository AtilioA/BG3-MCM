---@module "subscription"
local Subscription = Ext.Require("Lib/reactivex/subscription.lua")
---@module "util"
local util = Ext.Require("Lib/reactivex/util.lua")

--- INTERNAL: A specialized Subscription for Subjects. **This is NOT a public class,
--- it is intended for internal use only!**<br>
--- A handle representing the link between an Observer and a Subject, as well as any
--- work required to clean up after the Subject completes or the Observer unsubscribes.
--- @class SubjectSubscription : Subscription
--- @field _subject Subject
--- @field _observer Observer
local SubjectSubscription = setmetatable({}, Subscription)
SubjectSubscription.__index = SubjectSubscription
SubjectSubscription.__tostring = util.Constant('SubjectSubscription')

--- Creates a new SubjectSubscription.
--- @param subject Subject The action to run when the subscription is unsubscribed. It will only be run once.
--- @param observer Observer
--- @return Subscription
function SubjectSubscription.Create(subject, observer)
    local self = setmetatable(Subscription.Create(), SubjectSubscription)
    self._subject = subject
    self._observer = observer

    return self
end

--- Unsubscribes the subscription, performing any necessary cleanup work.
function SubjectSubscription:Unsubscribe()
    if self._unsubscribed then
        return
    end

    self._unsubscribed = true

    local subject = self._subject
    local observers = subject.observers

    self._subject = nil

    if not observers
        or #observers == 0
        or subject.stopped
        or subject._unsubscribed
    then
        return
    end

    for i = 1, #observers do
        if observers[i] == self._observer then
            table.remove(subject.observers, i)
            return
        end
    end
end

return SubjectSubscription
