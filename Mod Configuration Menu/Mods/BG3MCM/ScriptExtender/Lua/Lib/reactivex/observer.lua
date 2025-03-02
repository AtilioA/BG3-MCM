---@diagnostic disable: undefined-field
---@module "util"
local util = Ext.Require("Lib/reactivex/util.lua")
---@module "subscription"
local Subscription = Ext.Require("Lib/reactivex/subscription.lua")

--- Observers are simple objects that receive values from Observables.
--- @class Observer : Subscription
--- @field _onNext fun(values:...)
--- @field _onError fun(errorMessage:any)
--- @field _onCompleted fun()
--- @field _rawCallbacks table
--- @field _unsubscribed boolean
local Observer = setmetatable({}, Subscription)
Observer.__index = Observer
Observer.__tostring = util.Constant('Observer')

--- Creates a new Observer.
--- @generic T : any
--- @param ... function[] - onNext, onError, onCompleted
--- @overload fun(onNext:fun(T), onError:fun(errorMessage:string)?, onCompleted:fun()?)
--- @return Observer
function Observer.Create(...)
    local args = { ... }
    local argsCount = select('#', ...)
    local destinationOrNext, onError, onCompleted = args[1], args[2], args[3]
    local self = setmetatable(Subscription.Create(), Observer) --[[@as Observer]]
    self.stopped = false
    self._onNext = Observer.EMPTY._onNext
    self._onError = Observer.EMPTY._onError
    self._onCompleted = Observer.EMPTY._onCompleted
    self._rawCallbacks = {}

    if argsCount > 0 then
        if util.IsA(destinationOrNext, Observer) then
            self._onNext = destinationOrNext._onNext
            self._onError = destinationOrNext._onError
            self._onCompleted = destinationOrNext._onCompleted
            self._rawCallbacks = destinationOrNext._rawCallbacks
        else
            self._rawCallbacks.onNext = destinationOrNext
            self._rawCallbacks.onError = onError
            self._rawCallbacks.onCompleted = onCompleted

            self._onNext = function(...)
                if self._rawCallbacks.onNext then
                    self._rawCallbacks.onNext(...)
                end
            end
            self._onError = function(...)
                if self._rawCallbacks.onError then
                    self._rawCallbacks.onError(...)
                end
            end
            self._onCompleted = function()
                if self._rawCallbacks.onCompleted then
                    self._rawCallbacks.onCompleted()
                end
            end
        end
    end

    return self
end

--- Pushes zero or more values to the Observer.
--- @generic T : any
--- @param ... T values
function Observer:OnNext(...)
    if not self.stopped then
        self._onNext(...)
    end
end

--- Notify the Observer that an error has occurred.
---@param message string - A string describing what went wrong.
function Observer:OnError(message)
    if not self.stopped then
        self.stopped = true
        self._onError(message)
        self:Unsubscribe()
    end
end

--- Notify the Observer that the sequence has completed and will produce no more values.
function Observer:OnCompleted()
    if not self.stopped then
        self.stopped = true
        self._onCompleted()
        self:Unsubscribe()
    end
end

function Observer:Unsubscribe()
    if self._unsubscribed then
        return
    end

    self.stopped = true
    Subscription.Unsubscribe(self)
end

Observer.EMPTY = {
    _unsubscribed = true,
    _onNext = util.Noop,
    _onError = error,
    _onCompleted = util.Noop,
}

return Observer
