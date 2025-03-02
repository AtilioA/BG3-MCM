local util = Ext.Require("Lib/reactivex/util.lua")
local Subject -- lazy loaded to avoid loop
local Subscription = Ext.Require("Lib/reactivex/subscription.lua")
local _initialized = false

--- A specialized Subject which acts as a proxy when lifting a Subject.
--- **This is NOT a public class, it is intended for internal use only!**<br>
--- Its role is crucial to create a proper chain of operators / observables and to make
--- automatic unsubscription work correctly.
--- @class AnonymousSubject : Subject
--- @field _sourceSubject Subject
--- @field _createObserver Observer
local AnonymousSubject = {}
AnonymousSubject.__index = AnonymousSubject
AnonymousSubject.__tostring = util.Constant('AnonymousSubject')

local function lazyInitClass()
    if _initialized then return end
    Subject = Ext.Require("Lib/reactivex/subjects/subject.lua")
    setmetatable(AnonymousSubject, Subject)
    _initialized = true
end

---Internal only, do not use
---@param sourceSubject Subject
---@param createObserver Observer
---@return AnonymousSubject
function AnonymousSubject.Create(sourceSubject, createObserver)
    lazyInitClass()

    local self = setmetatable(Subject.Create(), AnonymousSubject)
    self._sourceSubject = sourceSubject
    self._createObserver = createObserver

    return self
end

function AnonymousSubject:OnNext(...)
    if self._sourceSubject and self._sourceSubject.OnNext then
        self._sourceSubject:OnNext(...)
    end
end

function AnonymousSubject:OnError(msg)
    if self._sourceSubject and self._sourceSubject.OnError then
        self._sourceSubject:OnError(msg)
    end
end

function AnonymousSubject:OnCompleted()
    if self._sourceSubject and self._sourceSubject.OnCompleted then
        self._sourceSubject:OnCompleted()
    end
end

function AnonymousSubject:_subscribe(destination)
    if self._sourceSubject then
        return self._sourceSubject:_subscribe(self._createObserver(destination))
    else
        return Subscription.EMPTY
    end
end

return AnonymousSubject
