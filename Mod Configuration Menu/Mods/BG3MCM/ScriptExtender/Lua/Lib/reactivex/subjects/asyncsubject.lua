local Observable = Ext.Require("Lib/reactivex/observable.lua")
local Observer = Ext.Require("Lib/reactivex/observer.lua")
local Subscription = Ext.Require("Lib/reactivex/subscription.lua")
local util = Ext.Require("Lib/reactivex/util.lua")

--- AsyncSubjects are subjects that produce either no values or a single value.  If
--- multiple values are produced via onNext, only the last one is used.  If onError is called, then
--- no value is produced and onError is called on any subscribed Observers.  If an Observer
--- subscribes and the AsyncSubject has already terminated, the Observer will immediately receive the
--- value or the error.
--- @class AsyncSubject : Observer,Observable
--- @field observers Observer[]
local AsyncSubject = setmetatable({}, Observable)
AsyncSubject.__index = AsyncSubject
AsyncSubject.__tostring = util.Constant('AsyncSubject')

--- Creates a new AsyncSubject.
--- @return AsyncSubject
function AsyncSubject.Create()
    local self = {
        observers = {},
        stopped = false,
        value = nil,
        errorMessage = nil
    }

    return setmetatable(self, AsyncSubject)
end

--- Creates a new Observer and attaches it to the AsyncSubject.
--- @param observerOrNext function|Observer - Called when the AsyncSubject produces a value.
--- @param onError function? - Called when the AsyncSubject terminates due to an error.
--- @param onCompleted function? - Called when the AsyncSubject completes normally.
--- @return Subscription|nil
function AsyncSubject:Subscribe(observerOrNext, onError, onCompleted)
    local observer --[[@as Observer]]

    if util.IsA(observerOrNext, Observer) then
        observer = observerOrNext
    else
        observer = Observer.Create(observerOrNext, onError, onCompleted)
    end

    if self.value then
        observer:OnNext(util.Unpack(self.value))
        observer:OnCompleted()
        return
    elseif self.errorMessage then
        observer:OnError(self.errorMessage)
        return
    end

    table.insert(self.observers, observer)

    return Subscription.Create(function()
        for i = 1, #self.observers do
            if self.observers[i] == observer then
                table.remove(self.observers, i)
                return
            end
        end
    end)
end

--- Pushes zero or more values to the AsyncSubject. They will be broadcasted to all Observers when the AsyncSubject completes.
--- @generic T : any
--- @param ... T
function AsyncSubject:OnNext(...)
    if not self.stopped then
        self.value = util.Pack(...)
    end
end

--- Notify the AsyncSubject that an error has occurred.
---@param message string - A string describing what went wrong.
function AsyncSubject:OnError(message)
    if not self.stopped then
        self.errorMessage = message

        for i = 1, #self.observers do
            self.observers[i]:OnError(self.errorMessage)
        end

        self.stopped = true
    end
end

--- Notify the AsyncSubject that the sequence has completed and will produce no more values.
function AsyncSubject:OnCompleted()
    if not self.stopped then
        for i = 1, #self.observers do
            if self.value then
                self.observers[i]:OnNext(util.Unpack(self.value))
            end

            self.observers[i]:OnCompleted()
        end

        self.stopped = true
    end
end

AsyncSubject.__call = AsyncSubject.OnNext

return AsyncSubject
