local Subject = Ext.Require("Lib/reactivex/subjects/subject.lua")
local Observer = Ext.Require("Lib/reactivex/observer.lua")
local util = Ext.Require("Lib/reactivex/util.lua")

--- A Subject that tracks its current value. Provides an accessor to retrieve the most
--- recent pushed value, and all subscribers immediately receive the latest value.
--- @class BehaviorSubject : Subject
local BehaviorSubject = setmetatable({}, Subject)
BehaviorSubject.__index = BehaviorSubject
BehaviorSubject.__tostring = util.Constant('BehaviorSubject')

--- Creates a new BehaviorSubject.
--- @param ... any - The initial values.
--- @return BehaviorSubject
function BehaviorSubject.Create(...)
    local self = {
        observers = {},
        stopped = false
    }

    if select('#', ...) > 0 then
        self.value = util.Pack(...)
    end

    return setmetatable(self, BehaviorSubject)
end

--- Creates a new Observer and attaches it to the BehaviorSubject. Immediately broadcasts the most
--- recent value to the Observer.
--- @param observerOrNext function|Observer - Called when the BehaviorSubject produces a value.
--- @param onError function? - Called when the BehaviorSubject terminates due to an error.
--- @param onCompleted function? - Called when the BehaviorSubject completes normally.
--- @return Subscription
function BehaviorSubject:Subscribe(observerOrNext, onError, onCompleted)
    local observer

    if util.IsA(observerOrNext, Observer) then
        observer = observerOrNext --[[@as Observer]]
    else
        observer = Observer.Create(observerOrNext, onError, onCompleted)
    end

    local subscription = Subject.Subscribe(self, observer)

    if self.value then
        observer:OnNext(util.Unpack(self.value))
    end

    return subscription
end

--- Pushes zero or more values to the BehaviorSubject. They will be broadcasted to all Observers.
--- @generic T : any
--- @param ... T
function BehaviorSubject:OnNext(...)
    self.value = util.Pack(...)
    return Subject.OnNext(self, ...)
end

--- Returns the last value emitted by the BehaviorSubject, or the initial value passed to the
--- constructor if nothing has been emitted yet.
--- @generic T : any
--- @return T|nil
function BehaviorSubject:GetValue()
    if self.value ~= nil then
        return util.Unpack(self.value)
    end
end

BehaviorSubject.__call = BehaviorSubject.OnNext

return BehaviorSubject
