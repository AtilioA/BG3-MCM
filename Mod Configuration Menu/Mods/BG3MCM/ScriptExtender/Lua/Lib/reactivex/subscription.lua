---@module "util"
local util = Ext.Require("Lib/reactivex/util.lua")

--- A handle representing the link between an Observer and an Observable, as well as any
--- work required to clean up after the Observable completes or the Observer unsubscribes.
--- @class Subscription
--- @field _unsubscribe function
local Subscription = {}
Subscription.__index = Subscription
Subscription.__tostring = util.Constant('Subscription')
Subscription.___isa = { Subscription }

--- Creates a new Subscription.
--- @param teardown fun(subscription: Subscription)? The action to run when the subscription is unsubscribed. It will only be run once.
--- @return Subscription
function Subscription.Create(teardown)
    local self = {
        _unsubscribe = teardown,
        _unsubscribed = false,
        _parentOrParents = nil,
        _subscriptions = nil,
    }

    return setmetatable(self, Subscription)
end

--- Returns whether the subscription is unsubscribed.
--- @return boolean
function Subscription:IsUnsubscribed()
    return self._unsubscribed
end

--- Unsubscribes the subscription, performing any necessary cleanup work.
function Subscription:Unsubscribe()
    if self._unsubscribed then return end

    -- copy some references which will be needed later
    local _parentOrParents = self._parentOrParents
    local _unsubscribe = self._unsubscribe
    local _subscriptions = self._subscriptions

    self._unsubscribed = true
    self._parentOrParents = nil

    -- null out _subscriptions first so any child subscriptions that attempt
    -- to remove themselves from this subscription will gracefully noop
    self._subscriptions = nil

    if util.IsA(_parentOrParents, Subscription) then
        _parentOrParents:Remove(self)
    elseif _parentOrParents ~= nil then
        for _, parent in ipairs(_parentOrParents) do
            parent:Remove(self)
        end
    end

    local errors

    if util.IsCallable(_unsubscribe) then
        local success, msg = pcall(_unsubscribe, self)

        if not success then
            errors = { msg }
        end
    end

    if type(_subscriptions) == 'table' then
        local index = 1
        local len = #_subscriptions

        while index <= len do
            local sub = _subscriptions[index]

            if type(sub) == 'table' then
                local success, msg = pcall(function() sub:Unsubscribe() end)

                if not success then
                    errors = errors or {}
                    table.insert(errors, msg)
                end
            end

            index = index + 1
        end
    end

    if errors then
        error(table.concat(errors, '; '))
    end
end

--- Adds a teardown function or subscription to this subscription.
--- @param teardown function|Subscription
--- @return Subscription
function Subscription:Add(teardown)
    if not teardown then
        return Subscription.EMPTY
    end

    local subscription = teardown

    if util.IsCallable(teardown)
        and not util.IsA(teardown, Subscription)
    then
        subscription = Subscription.Create(teardown --[[@as function]])
    end

    if type(subscription) == 'table' then
        if subscription == self or subscription._unsubscribed or type(subscription.Unsubscribe) ~= 'function' then
            -- This also covers the case where `subscription` is `Subscription.EMPTY`, which is always unsubscribed
            return subscription
        elseif self._unsubscribed then
            subscription:Unsubscribe()
            return subscription
        elseif not util.IsA(teardown, Subscription) then
            local tmp = subscription
            subscription = Subscription.Create()
            subscription._subscriptions = { tmp }
        end
    else
        error('unrecognized teardown ' .. tostring(teardown) .. ' added to Subscription')
    end

    local _parentOrParents = subscription._parentOrParents

    if _parentOrParents == nil then
        subscription._parentOrParents = self
    elseif util.IsA(_parentOrParents, Subscription) then
        if _parentOrParents == self then
            return subscription
        end

        subscription._parentOrParents = { _parentOrParents, self }
    else
        local found = false

        for _, existingParent in ipairs(_parentOrParents) do
            if existingParent == self then
                found = true
            end
        end

        if not found then
            table.insert(_parentOrParents, self)
        else
            return subscription
        end
    end

    local subscriptions = self._subscriptions

    if subscriptions == nil then
        self._subscriptions = { subscription }
    else
        table.insert(subscriptions, subscription)
    end

    return subscription
end

--- Removes a subscription from this subscription.
--- @param subscription Subscription
function Subscription:Remove(subscription)
    local subscriptions = self._subscriptions

    if subscriptions then
        for i, existingSubscription in ipairs(subscriptions) do
            if existingSubscription == subscription then
                table.remove(subscriptions, i)
                return
            end
        end
    end
end

Subscription.EMPTY = (function(sub)
    sub._unsubscribed = true
    return sub
end)(Subscription.Create())

return Subscription
