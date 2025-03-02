---@module "util"
local util = Ext.Require("Lib/reactivex/util.lua")
---@module "observer"
local Observer = Ext.Require("Lib/reactivex/observer.lua")
---@module "subscription"
local Subscription = Ext.Require("Lib/reactivex/subscription.lua")

--- Observables push values to Observers.
--- @class Observable
local Observable = {}
Observable.__index = Observable
Observable.__tostring = util.Constant('Observable')
Observable.___isa = { Observable }

--- Creates a new Observable. Please note that the Observable does not do any work right after creation, but only after calling a `subscribe` on it.
---@param subscribe fun(observer: Observer)? any # The subscription function that produces values. It is called when the Observable is initially subscribed to. This function is given an Observer, to which new values can be `onNext`ed, or an `onError` method can be called to raise an error, or `onCompleted` can be called to notify of a successful completion.
---@return Observable
function Observable.Create(subscribe)
    local self = {}

    if subscribe then
        self._subscribe = function(self, ...) return subscribe(...) end
    end

    return setmetatable(self, Observable)
end

--- Creates a new Observable, with this Observable as the source. It must be used internally by operators to create a proper chain of observables.
--- @param createObserver Observer|function observer factory function
--- @return Observable # a new observable chained with the source observable
function Observable:Lift(createObserver)
    local this = self

    return Observable.Create(function(observer)
        return this:Subscribe(createObserver(observer))
    end)
end

--- Invokes an execution of an Observable and registers Observer handlers for notifications it will emit.
--- @param observerOrNext Observer|fun(...)? Called when the Observable produces a value.
--- @param onError fun(message: string)? Called when the Observable terminates due to an error.
--- @param onCompleted fun()? Called when the Observable completes normally.
--- @return Subscription # a Subscription object which you can call `unsubscribe` on to stop all work that the Observable does.
function Observable:Subscribe(observerOrNext, onError, onCompleted)
    local sink

    if util.IsA(observerOrNext, Observer) then
        sink = observerOrNext --[[@as Observer]]
    else
        sink = Observer.Create(observerOrNext, onError, onCompleted)
    end

    -- _subscribe is internal use
    ---@diagnostic disable-next-line: undefined-field
    sink:Add(self:_subscribe(sink))

    return sink --[[@as Subscription]]
end

--- Returns an Observable that immediately completes without producing a value.
function Observable.Empty()
    return Observable.Create(function(observer)
        observer:OnCompleted()
    end)
end

--- Returns an Observable that never produces values and never completes.
function Observable.Never()
    return Observable.Create(function( --[[observer]]) end)
end

--- Returns an Observable that immediately produces an error.
--- @param message string
function Observable.Throw(message)
    return Observable.Create(function(observer)
        observer:OnError(message)
    end)
end

--- Creates an Observable that produces a set of values.
---@generic T : any
---@param ... T *...
---@return Observable
function Observable.Of(...)
    local args = { ... }
    local argCount = select('#', ...)
    return Observable.Create(function(observer)
        for i = 1, argCount do
            observer:OnNext(args[i])
        end

        observer:OnCompleted()
    end)
end

--- Creates an Observable that produces a range of values in a manner similar to a Lua for loop.
---@param initial number - The first value of the range, or the upper limit if no other arguments are specified.
---@param limit number - The second value of the range.
---@param step number? - An amount to increment the value by each iteration.
---@return Observable
function Observable.FromRange(initial, limit, step)
    if not limit and not step then
        initial, limit = 1, initial
    end

    step = step or 1

    return Observable.Create(function(observer)
        for i = initial, limit, step do
            observer:OnNext(i)
        end

        observer:OnCompleted()
    end)
end

--- Creates an Observable that produces values from a table.
--- @generic K, V
--- @param t table - The table used to create the Observable.
--- @param iterator fun(table: table<K, V>, index?: K):K, V - An iterator used to iterate the table, e.g. pairs or ipairs.
--- @param keys boolean - Whether or not to also emit the keys of the table.
---@return Observable
function Observable.FromTable(t, iterator, keys)
    iterator = iterator or pairs
    return Observable.Create(function(observer)
        for key, value in iterator(t) do
            observer:OnNext(value, keys and key or nil)
        end

        observer:OnCompleted()
    end)
end

--- Creates an Observable that produces values when the specified coroutine yields.
--- @param fn thread|function A coroutine or function to use to generate values.  Note that if a coroutine is used, the values it yields will be shared by all subscribed Observers (influenced by the Scheduler), whereas a new coroutine will be created for each Observer when a function is used.
--- @param scheduler Scheduler
---@return Observable
function Observable.FromCoroutine(fn, scheduler)
    return Observable.Create(function(observer)
        local thread = type(fn) == 'function' and coroutine.create(fn) or fn --[[@as thread]]
        return scheduler:Schedule(function()
            while not observer.stopped do
                local success, value = coroutine.resume(thread)

                if success then
                    observer:OnNext(value)
                else
                    return observer:OnError(value)
                end

                if coroutine.status(thread) == 'dead' then
                    return observer:OnCompleted()
                end

                coroutine.yield()
            end
        end)
    end)
end

--- Creates an Observable that produces values from a file, line by line.
---@param filename string - The name of the file used to create the Observable
---@return Observable
function Observable.FromFileByLine(filename)
    return Observable.Create(function(observer)
        local file = io.open(filename, 'r')
        if file then
            file:close()

            for line in io.lines(filename) do
                observer:OnNext(line)
            end

            return observer:OnCompleted()
        else
            return observer:OnError(filename)
        end
    end)
end

--- Creates an Observable that creates a new Observable for each observer using a factory function.
---@param fn fun():Observable - A function that returns an Observable.
---@return Observable
function Observable.Defer(fn)
    if not fn or type(fn) ~= 'function' then
        error('Expected a function')
    end

    return setmetatable({
        Subscribe = function(_, ...)
            local observable = fn()
            return observable:Subscribe(...)
        end
    }, Observable)
end

--- Returns an Observable that repeats a value a specified number of times.
---@generic T : any
---@param value T The value to repeat.
---@param count number - The number of times to repeat the value.  If left unspecified, the value is repeated an infinite number of times.
---@return Observable
function Observable.Replicate(value, count)
    return Observable.Create(function(observer)
        while count == nil or count > 0 do
            observer:OnNext(value)
            if count then
                count = count - 1
            end
        end
        observer:OnCompleted()
    end)
end

--- Subscribes to this Observable and prints values it produces.
---@param name string - Prefixes the printed messages with a name.
---@param formatter function [tostring] - A function that formats one or more values to be printed.
function Observable:Dump(name, formatter)
    name = name and (name .. ' ') or ''
    formatter = formatter or tostring

    local onNext = function(...) print(name .. 'OnNext: ' .. formatter(...)) end
    local onError = function(e) print(name .. 'OnError: ' .. e) end
    local onCompleted = function() print(name .. 'OnCompleted') end

    return self:Subscribe(onNext, onError, onCompleted)
end

--#region Operators

--- Determine whether all items emitted by an Observable meet some criteria.
---@param predicate fun(x: any): any [identity] - The predicate used to evaluate objects.
function Observable:All(predicate)
    predicate = predicate or util.Identity

    return self:Lift(function(destination)
        local function onNext(...)
            util.TryWithObserver(destination, function(...)
                if not predicate(...) then
                    destination:OnNext(false)
                    destination:OnCompleted()
                end
            end, ...)
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            destination:OnNext(true)
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Given a set of Observables, produces values from only the first one to produce a value.
---@param a Observable first
---@param b Observable second
---@param ... Observable onNextA or onNextB
---@return Observable
function Observable.Amb(a, b, ...)
    if not a or not b then return a end

    return Observable.Create(function(observer)
        local subscriptionA, subscriptionB

        local function onNextA(...)
            if subscriptionB then subscriptionB:Unsubscribe() end
            observer:OnNext(...)
        end

        local function onErrorA(e)
            if subscriptionB then subscriptionB:Unsubscribe() end
            observer:OnError(e)
        end

        local function onCompletedA()
            if subscriptionB then subscriptionB:Unsubscribe() end
            observer:OnCompleted()
        end

        local function onNextB(...)
            if subscriptionA then subscriptionA:Unsubscribe() end
            observer:OnNext(...)
        end

        local function onErrorB(e)
            if subscriptionA then subscriptionA:Unsubscribe() end
            observer:OnError(e)
        end

        local function onCompletedB()
            if subscriptionA then subscriptionA:Unsubscribe() end
            observer:OnCompleted()
        end

        subscriptionA = a:Subscribe(onNextA, onErrorA, onCompletedA)
        subscriptionB = b:Subscribe(onNextB, onErrorB, onCompletedB)

        return Subscription.Create(function()
            subscriptionA:Unsubscribe()
            subscriptionB:Unsubscribe()
        end)
    end):Amb(...)
end

--- Returns an Observable that produces the average of all values produced by the original.
--- @return Observable
function Observable:Average()
    return self:Lift(function(destination)
        local sum, count = 0, 0

        local function onNext(value)
            sum = sum + value
            count = count + 1
        end

        local function onError(e)
            destination:OnError(e)
        end

        local function onCompleted()
            if count > 0 then
                destination:OnNext(sum / count)
            end

            destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns an Observable that buffers values from the original and produces them as multiple values.
---@param size number - The size of the buffer.
function Observable:Buffer(size)
    if not size or type(size) ~= 'number' then
        error('Expected a number')
    end

    return self:Lift(function(destination)
        local buffer = {}

        local function emit()
            if #buffer > 0 then
                destination:OnNext(util.Unpack(buffer))
                buffer = {}
            end
        end

        local function onNext(...)
            local values = { ... }
            for i = 1, #values do
                table.insert(buffer, values[i])
                if #buffer >= size then
                    emit()
                end
            end
        end

        local function onError(message)
            emit()
            return destination:OnError(message)
        end

        local function onCompleted()
            emit()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that intercepts any errors from the previous and replace them with values produced by a new Observable.
---@param handler function|Observable - An Observable or a function that returns an Observable to replace the source Observable in the event of an error.
---@return Observable
function Observable:Catch(handler)
    handler = handler and (type(handler) == 'function' and handler or util.Constant(handler))

    return self:Lift(function(destination)
        local function onNext(...)
            return destination:OnNext(...)
        end

        local function onError(e)
            if not handler then
                return destination:OnCompleted()
            end

            local success, _continue = pcall(handler, e)

            if success and _continue then
                _continue:Subscribe(destination)
            else
                destination:OnError(_continue)
            end
        end

        local function onCompleted()
            destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that runs a combinator function on the most recent values from a set
--- of Observables whenever any of them produce a new value. The results of the combinator function
--- are produced by the new Observable.
--- @param ... Observable - One or more Observables to combine.
-- - @param ... combinator - last arg = A function that combines the latest result from each Observable and returns a single value.
---@return Observable
function Observable:CombineLatest(...)
    local sources = { ... }
    local combinator = table.remove(sources)
    if not util.IsCallable(combinator) then
        table.insert(sources, combinator)
        combinator = function(...) return ... end
    end
    table.insert(sources, 1, self)

    return self:Lift(function(destination)
        local latest = {}
        local pending = { util.Unpack(sources) }
        local completedCount = 0

        local function createOnNext(i)
            return function(value)
                latest[i] = value
                pending[i] = nil

                if not next(pending) then
                    util.TryWithObserver(destination, function()
                        destination:OnNext(combinator(util.Unpack(latest)))
                    end)
                end
            end
        end

        local function onError(e)
            return destination:OnError(e)
        end

        ---@diagnostic disable-next-line: unused-local
        local function createOnCompleted(i)
            return function()
                completedCount = completedCount + 1

                if completedCount == #sources then
                    destination:OnCompleted()
                end
            end
        end

        local sink = Observer.Create(createOnNext(1), onError, createOnCompleted(1))

        for i = 2, #sources do
            sink:Add(sources[i]:Subscribe(createOnNext(i), onError, createOnCompleted(i)))
        end

        return sink
    end)
end

--- Returns a new Observable that produces the values of the first with falsy values removed.
---@return Observable
function Observable:Compact()
    return self:Filter(util.Identity)
end

--- Returns a new Observable that produces the values produced by all the specified Observables in the order they are specified.
---@param other Observable
---@param ... Observable - The Observables to concatenate.
---@return Observable
function Observable:Concat(other, ...)
    if not other then return self end

    local others = { ... }

    return self:Lift(function(destination)
        local function onNext(...)
            return destination:OnNext(...)
        end

        local function onError(message)
            return destination:OnError(message)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        local function chain()
            other:Concat(util.Unpack(others)):Subscribe(onNext, onError, onCompleted)
        end

        return Observer.Create(onNext, onError, chain)
    end)
end

--- Returns a new Observable that produces a single boolean value representing whether or not the specified value was produced by the original.
--- @generic T : any
--- @param value T - The value to search for.  == is used for equality testing.
---@return Observable
function Observable:Contains(value)
    return self:Lift(function(destination)
        local function onNext(...)
            local args = util.Pack(...)

            if #args == 0 and value == nil then
                destination:OnNext(true)
                return destination:OnCompleted()
            end

            for i = 1, #args do
                if args[i] == value then
                    destination:OnNext(true)
                    return destination:OnCompleted()
                end
            end
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            destination:OnNext(false)
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns an Observable that produces a single value representing the number of values produced by the source value that satisfy an optional predicate.
--- @param predicate function - The predicate used to match values.
function Observable:Count(predicate)
    predicate = predicate or util.Constant(true)

    return self:Lift(function(destination)
        local count = 0

        local function onNext(...)
            util.TryWithObserver(destination, function(...)
                if predicate(...) then
                    count = count + 1
                end
            end, ...)
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            destination:OnNext(count)
            destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new throttled Observable that waits to produce values until a timeout has expired, at which point it produces the latest value from the source Observable.  Whenever the source Observable produces a value, the timeout is reset.
--- @param time number - An amount in milliseconds to wait before producing the last value.
--- @param scheduler Scheduler - The scheduler to run the Observable on.
---@return Observable
function Observable:Debounce(time, scheduler)
    time = time or 0

    return self:Lift(function(destination)
        local debounced = {}
        local sink

        local function wrap(key)
            return function(...)
                if debounced[key] then
                    debounced[key]:Unsubscribe()
                    sink:Remove(debounced[key])
                end

                local values = util.Pack(...)

                debounced[key] = scheduler:Schedule(function()
                    return destination[key](destination, util.Unpack(values))
                end, time)
                sink:Add(debounced[key])
            end
        end

        sink = Observer.Create(wrap('OnNext'), wrap('OnError'), wrap('OnCompleted'))

        return sink
    end)
end

--- Returns a new Observable that produces a default set of items if the source Observable produces no values.
--- @generic T : any
--- @param ... T? values *... - Zero or more values to produce if the source completes without emitting anything.
---@return Observable
function Observable:DefaultIfEmpty(...)
    local defaults = util.Pack(...)

    return self:Lift(function(destination)
        local hasValue = false

        local function onNext(...)
            hasValue = true
            destination:OnNext(...)
        end

        local function onError(e)
            destination:OnError(e)
        end

        local function onCompleted()
            if not hasValue then
                destination:OnNext(util.Unpack(defaults))
            end

            destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that produces the values of the original delayed by a time period.
--- @param time number|function - An amount in milliseconds to delay by, or a function which returns this value.
--- @param scheduler Scheduler - The scheduler to run the Observable on.
---@return Observable
function Observable:Delay(time, scheduler)
    time = type(time) ~= 'function' and util.Constant(time) or time

    return self:Lift(function(destination)
        local sink

        local function delay(key)
            return function(...)
                local arg = util.Pack(...)
                sink:Add(scheduler:Schedule(function()
                    destination[key](destination, util.Unpack(arg))
                end, time()))
            end
        end

        sink = Observer.Create(delay('OnNext'), delay('OnError'), delay('OnCompleted'))

        return sink
    end)
end

--- Returns a new Observable that produces the values from the original with duplicates removed.
---@return Observable
function Observable:Distinct()
    return self:Lift(function(destination)
        local values = {}

        local function onNext(x)
            if not values[x] then
                destination:OnNext(x)
            end

            values[x] = true
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns an Observable that only produces values from the original if they are different from the previous value.
---@param comparator function - A function used to compare 2 values. If unspecified, == is used.
---@return Observable
function Observable:DistinctUntilChanged(comparator)
    comparator = comparator or util.Eq

    return self:Lift(function(destination)
        local first = true
        local currentValue = nil

        local function onNext(value, ...)
            local values = util.Pack(...)
            util.TryWithObserver(destination, function()
                if first or not comparator(value, currentValue) then
                    destination:OnNext(value, util.Unpack(values))
                    currentValue = value
                    first = false
                end
            end)
        end

        local function onError(message)
            return destination:OnError(message)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns an Observable that produces the nth element produced by the source Observable.
--- @param index number - The index of the item, with an index of 1 representing the first.
---@return Observable
function Observable:ElementAt(index)
    if not index or type(index) ~= 'number' then
        error('Expected a number')
    end

    return self:Lift(function(destination)
        local i = 1

        local function onNext(...)
            if i == index then
                destination:OnNext(...)
                destination:OnCompleted()
            else
                i = i + 1
            end
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that only produces values of the first that satisfy a predicate.
--- @param predicate function - The predicate used to filter values.
---@return Observable
function Observable:Filter(predicate)
    predicate = predicate or util.Identity

    return self:Lift(function(destination)
        local function onNext(...)
            util.TryWithObserver(destination, function(...)
                if predicate(...) then
                    destination:OnNext(...)
                    return
                end
            end, ...)
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that produces the first value of the original that satisfies a predicate.
--- @param predicate function - The predicate used to find a value.
function Observable:Find(predicate)
    predicate = predicate or util.Identity

    return self:Lift(function(destination)
        local function onNext(...)
            util.TryWithObserver(destination, function(...)
                if predicate(...) then
                    destination:OnNext(...)
                    return destination:OnCompleted()
                end
            end, ...)
        end

        local function onError(message)
            return destination:OnError(message)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that only produces the first result of the original.
---@return Observable
function Observable:First()
    return self:Take(1)
end

--- Returns a new Observable that transform the items emitted by an Observable into Observables, then flatten the emissions from those into a single Observable
--- @param callback function - The function to transform values from the original Observable.
---@return Observable
function Observable:FlatMap(callback)
    callback = callback or util.Identity
    return self:Map(callback):Flatten()
end

--- Returns a new Observable that uses a callback to create Observables from the values produced by the source, then produces values from the most recent of these Observables.
--- @param callback function [identity] - The function used to convert values to Observables.
---@return Observable
function Observable:FlatMapLatest(callback)
    callback = callback or util.Identity
    return self:Lift(function(destination)
        local innerSubscription
        local sink

        local function onNext(...)
            destination:OnNext(...)
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        local function subscribeInner(...)
            if innerSubscription then
                innerSubscription:Unsubscribe()
                sink:Remove(innerSubscription)
            end

            return util.TryWithObserver(destination, function(...)
                innerSubscription = callback(...):Subscribe(onNext, onError)
                sink:Add(innerSubscription)
            end, ...)
        end

        sink = Observer.Create(subscribeInner, onError, onCompleted)
        return sink
    end)
end

--- Returns a new Observable that subscribes to the Observables produced by the original and produces their values.
---@return Observable
function Observable:Flatten()
    return self:Lift(function(destination)
        local sink

        local function onError(message)
            return destination:OnError(message)
        end

        local function onNext(observable)
            local function innerOnNext(...)
                destination:OnNext(...)
            end

            sink:Add(observable:Subscribe(innerOnNext, onError, util.Noop))
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        sink = Observer.Create(onNext, onError, onCompleted)

        return sink
    end)
end

--- Returns an Observable that terminates when the source terminates but does not produce any elements.
---@return Observable
function Observable:IgnoreElements()
    return self:Lift(function(destination)
        local function onError(message)
            return destination:OnError(message)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(nil, onError, onCompleted)
    end)
end

--- Returns a new Observable that only produces the last result of the original.
---@return Observable
function Observable:Last()
    return self:Lift(function(destination)
        local value
        local empty = true

        local function onNext(...)
            value = { ... }
            empty = false
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            if not empty then
                destination:OnNext(util.Unpack(value or {}))
            end

            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that produces the values of the original transformed by a function.
--- @param callback function - The function to transform values from the original Observable.
---@return Observable
function Observable:Map(callback)
    return self:Lift(function(destination)
        callback = callback or util.Identity

        local function onNext(...)
            return util.TryWithObserver(destination, function(...)
                return destination:OnNext(callback(...))
            end, ...)
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that produces the maximum value produced by the original.
---@return Observable
function Observable:Max()
    return self:Reduce(math.max)
end

--- Returns a new Observable that produces the values produced by all the specified Observables in the order they are produced.
---@param ... Observable - One or more Observables to merge.
---@return Observable
function Observable:Merge(...)
    local sources = { ... }
    table.insert(sources, 1, self)

    return self:Lift(function(destination)
        local completedCount = 0

        local function onNext(...)
            return destination:OnNext(...)
        end

        local function onError(message)
            return destination:OnError(message)
        end

        ---@diagnostic disable-next-line: unused-local
        local function onCompleted(i)
            return function()
                completedCount = completedCount + 1

                if completedCount == #sources then
                    destination:OnCompleted()
                end
            end
        end

        local sink = Observer.Create(onNext, onError, onCompleted(1))

        for i = 2, #sources do
            sink:Add(sources[i]:Subscribe(onNext, onError, onCompleted(i)))
        end

        return sink
    end)
end

--- Returns a new Observable that produces the minimum value produced by the original.
---@return Observable
function Observable:Min()
    return self:Reduce(math.min)
end

--- Returns an Observable that produces the values of the original inside tables.
---@return Observable
function Observable:Pack()
    return self:Map(util.Pack)
end

--- Returns two Observables: one that produces values for which the predicate returns truthy for, and another that produces values for which the predicate returns falsy.
---@param predicate function - The predicate used to partition the values.
---@return Observable, Observable
function Observable:Partition(predicate)
    return self:Filter(predicate), self:Reject(predicate)
end

--- Returns a new Observable that produces values computed by extracting the given keys from the tables produced by the original.
--- @param key string|nil - The key to extract from the table. (*nil for recursion)
--- @param ... string? - Multiple keys can be specified to recursively pluck values from nested tables.
---@return Observable
function Observable:Pluck(key, ...)
    if not key then return self end

    if type(key) ~= 'string' and type(key) ~= 'number' then
        return Observable.Throw('pluck key must be a string')
    end

    return self:Lift(function(destination)
        local function onNext(t)
            return destination:OnNext(t[key])
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end):Pluck(...)
end

--- Returns a new Observable that produces a single value computed by accumulating the results of running a function on each value produced by the original Observable.
--- @param accumulator function - Accumulates the values of the original Observable. Will be passed the return value of the last call as the first argument and the current values as the rest of the arguments.
--- @param seed any - A value to pass to the accumulator the first time it is run.
---@return Observable
function Observable:Reduce(accumulator, seed)
    return self:Lift(function(destination)
        local result = seed
        local first = true

        local function onNext(...)
            if first and seed == nil then
                result = ...
                first = false
            else
                return util.TryWithObserver(destination, function(...)
                    result = accumulator(result, ...)
                end, ...)
            end
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            destination:OnNext(result)
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that produces values from the original which do not satisfy a predicate.
--- @param predicate function - The predicate used to reject values.
---@return Observable
function Observable:Reject(predicate)
    predicate = predicate or util.Identity

    return self:Lift(function(destination)
        local function onNext(...)
            util.TryWithObserver(destination, function(...)
                if not predicate(...) then
                    return destination:OnNext(...)
                end
            end, ...)
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns an Observable that restarts in the event of an error.
--- @param count number - The maximum number of times to retry.  If left unspecified, an infinite number of retries will be attempted.
---@return Observable
function Observable:Retry(count)
    return self:Lift(function(destination)
        local subscription
        local sink
        local retries = 0

        local function onNext(...)
            return destination:OnNext(...)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        local function onError(message)
            if subscription then
                subscription:Unsubscribe()
                sink:Remove(subscription)
            end

            retries = retries + 1
            if count and retries > count then
                return destination:OnError(message)
            end

            subscription = self:Subscribe(onNext, onError, onCompleted)
            sink:Add(subscription)
        end

        sink = Observer.Create(onNext, onError, onCompleted)

        return sink
    end)
end

--- Returns a new Observable that produces its most recent value every time the specified observable produces a value.
---@param sampler Observable - The Observable that is used to sample values from this Observable.
---@return Observable
function Observable:Sample(sampler)
    if not sampler then error('Expected an Observable') end

    return self:Lift(function(destination)
        local latest = {}

        local function setLatest(...)
            latest = util.Pack(...)
        end

        local function onNext()
            if #latest > 0 then
                return destination:OnNext(util.Unpack(latest))
            end
        end

        local function onError(message)
            return destination:OnError(message)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        local sink = Observer.Create(setLatest, onError)
        sink:Add(sampler:Subscribe(onNext, onError, onCompleted))

        return sink
    end)
end

--- Returns a new Observable that produces values computed by accumulating the results of running a function on each value produced by the original Observable.
--- @param accumulator function - Accumulates the values of the original Observable. Will be passed the return value of the last call as the first argument and the current values as the rest of the arguments.  Each value returned from this function will be emitted by the Observable.
--- @param seed any - A value to pass to the accumulator the first time it is run.
---@return Observable
function Observable:Scan(accumulator, seed)
    return self:Lift(function(destination)
        local result = seed
        local first = true

        local function onNext(...)
            if first and seed == nil then
                result = ...
                first = false
            else
                return util.TryWithObserver(destination, function(...)
                    result = accumulator(result, ...)
                    destination:OnNext(result)
                end, ...)
            end
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that skips over a specified number of values produced by the original and produces the rest.
--- @param n number [or 1] - The number of values to ignore.
---@return Observable
function Observable:Skip(n)
    n = n or 1

    return self:Lift(function(destination)
        local i = 1

        local function onNext(...)
            if i > n then
                destination:OnNext(...)
            else
                i = i + 1
            end
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns an Observable that omits a specified number of values from the end of the original Observable.
--- @param count number - The number of items to omit from the end.
---@return Observable
function Observable:SkipLast(count)
    if not count or type(count) ~= 'number' then
        error('Expected a number')
    end

    local buffer = {}
    return self:Lift(function(destination)
        local function emit()
            if #buffer > count and buffer[1] then
                local values = table.remove(buffer, 1)
                destination:OnNext(util.Unpack(values))
            end
        end

        local function onNext(...)
            emit()
            table.insert(buffer, util.Pack(...))
        end

        local function onError(message)
            return destination:OnError(message)
        end

        local function onCompleted()
            emit()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that skips over values produced by the original until the specified Observable produces a value.
---@param other Observable - The Observable that triggers the production of values.
---@return Observable
function Observable:SkipUntil(other)
    return self:Lift(function(destination)
        local triggered = false
        local function trigger()
            triggered = true
        end

        other:Subscribe(trigger, trigger, trigger)

        local function onNext(...)
            if triggered then
                destination:OnNext(...)
            end
        end

        local function onError()
            if triggered then
                destination:OnError()
            end
        end

        local function onCompleted()
            if triggered then
                destination:OnCompleted()
            end
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that skips elements until the predicate returns falsy for one of them.
--- @param predicate function - The predicate used to continue skipping values.
---@return Observable
function Observable:SkipWhile(predicate)
    predicate = predicate or util.Identity

    return self:Lift(function(destination)
        local skipping = true

        local function onNext(...)
            if skipping then
                util.TryWithObserver(destination, function(...)
                    skipping = predicate(...)
                end, ...)
            end

            if not skipping then
                return destination:OnNext(...)
            end
        end

        local function onError(message)
            return destination:OnError(message)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that produces the specified values followed by all elements produced by the source Observable.
--- @param ... any - The values to produce before the Observable begins producing values normally.
---@return Observable
function Observable:StartWith(...)
    local values = util.Pack(...)
    return self:Lift(function(destination)
        destination:OnNext(util.Unpack(values))
        return destination
    end)
end

--- Returns an Observable that produces a single value representing the sum of the values produced by the original.
---@return Observable
function Observable:Sum()
    return self:Reduce(function(x, y) return x + y end, 0)
end

--- Given an Observable that produces Observables, returns an Observable that produces the values produced by the most recently produced Observable.
---@return Observable
function Observable:Switch()
    return self:Lift(function(destination)
        local innerSubscription
        local sink

        local function onNext(...)
            return destination:OnNext(...)
        end

        local function onError(message)
            return destination:OnError(message)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        local function switch(source)
            if innerSubscription then
                innerSubscription:Unsubscribe()
                sink:Remove(innerSubscription)
            end

            innerSubscription = source:Subscribe(onNext, onError, nil)
            sink:Add(innerSubscription)
        end

        sink = Observer.Create(switch, onError, onCompleted)

        return sink
    end)
end

--- Returns a new Observable that only produces the first n results of the original.
---@param n number [or 1] - The number of elements to produce before completing.
---@return Observable
function Observable:Take(n)
    n = n or 1

    return self:Lift(function(destination)
        if n <= 0 then
            destination:OnCompleted()
            return
        end

        local i = 1

        local function onNext(...)
            destination:OnNext(...)

            i = i + 1

            if i > n then
                destination:OnCompleted()
                destination:Unsubscribe()
            end
        end

        local function onError(e)
            destination:OnError(e)
        end

        local function onCompleted()
            destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns an Observable that produces a specified number of elements from the end of a source Observable.
---@param count number - The number of elements to produce.
---@return Observable
function Observable:TakeLast(count)
    if not count or type(count) ~= 'number' then
        error('Expected a number')
    end

    return self:Lift(function(destination)
        local buffer = {}

        local function onNext(...)
            table.insert(buffer, util.Pack(...))
            if #buffer > count then
                table.remove(buffer, 1)
            end
        end

        local function onError(message)
            return destination:OnError(message)
        end

        local function onCompleted()
            for i = 1, #buffer do
                destination:OnNext(util.Unpack(buffer[i]))
            end
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that completes when the specified Observable fires.
---@param other Observable - The Observable that triggers completion of the original.
---@return Observable
function Observable:TakeUntil(other)
    return self:Lift(function(destination)
        local function onNext(...)
            return destination:OnNext(...)
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        other:Subscribe(onCompleted, onCompleted, onCompleted)

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns a new Observable that produces elements until the predicate returns falsy.
--- @param predicate function - The predicate used to continue production of values.
---@return Observable
function Observable:TakeWhile(predicate)
    predicate = predicate or util.Identity

    return self:Lift(function(destination)
        local taking = true

        local function onNext(...)
            if taking then
                util.TryWithObserver(destination, function(...)
                    taking = predicate(...)
                end, ...)

                if taking then
                    return destination:OnNext(...)
                else
                    return destination:OnCompleted()
                end
            end
        end

        local function onError(message)
            return destination:OnError(message)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Runs a function each time this Observable has activity. Similar to subscribe but does not create a subscription.
--- @param _onNext fun(...)? - Run when the Observable produces values.
--- @param _onError fun(message:string)? - Run when the Observable encounters a problem.
--- @param _onCompleted function? - Run when the Observable completes.
---@return Observable
function Observable:Tap(_onNext, _onError, _onCompleted)
    _onNext = _onNext or util.Noop
    _onError = _onError or util.Noop
    _onCompleted = _onCompleted or util.Noop

    return self:Lift(function(destination)
        local function onNext(...)
            util.TryWithObserver(destination, function(...)
                _onNext(...)
            end, ...)

            return destination:OnNext(...)
        end

        local function onError(message)
            util.TryWithObserver(destination, function()
                _onError(message)
            end)

            return destination:OnError(message)
        end

        local function onCompleted()
            util.TryWithObserver(destination, function()
                _onCompleted()
            end)

            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns an Observable that unpacks the tables produced by the original.
---@return Observable
function Observable:Unpack()
    return self:Map(util.Unpack)
end

--- Returns an Observable that takes any values produced by the original that consist of multiple return values and produces each value individually.
---@return Observable
function Observable:Unwrap()
    return self:Lift(function(destination)
        local function onNext(...)
            local values = { ... }
            for i = 1, #values do
                destination:OnNext(values[i])
            end
        end

        local function onError(message)
            return destination:OnError(message)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns an Observable that produces a sliding window of the values produced by the original.
--- @param size number - The size of the window. The returned observable will produce this number of the most recent values as multiple arguments to onNext.
---@return Observable
function Observable:Window(size)
    if not size or type(size) ~= 'number' then
        error('Expected a number')
    end

    return self:Lift(function(destination)
        local window = {}

        local function onNext(value)
            table.insert(window, value)

            if #window >= size then
                destination:OnNext(util.Unpack(window))
                table.remove(window, 1)
            end
        end

        local function onError(message)
            return destination:OnError(message)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        return Observer.Create(onNext, onError, onCompleted)
    end)
end

--- Returns an Observable that produces values from the original along with the most recently produced value from all other specified Observables. Note that only the first argument from each source Observable is used.
--- @param ... Observable - The Observables to include the most recent values from.
---@return Observable
function Observable:With(...)
    local sources = { ... }

    return self:Lift(function(destination)
        local latest = setmetatable({}, { __len = util.Constant(#sources) })

        local function setLatest(i)
            return function(value)
                latest[i] = value
            end
        end

        local function onNext(value)
            return destination:OnNext(value, util.Unpack(latest))
        end

        local function onError(e)
            return destination:OnError(e)
        end

        local function onCompleted()
            return destination:OnCompleted()
        end

        local sink = Observer.Create(onNext, onError, onCompleted)

        for i = 1, #sources do
            sink:Add(sources[i]:Subscribe(setLatest(i), util.Noop, util.Noop))
        end

        return sink
    end)
end

--- Returns an Observable that merges the values produced by the source Observables by grouping them
--- by their index.  The first onNext event contains the first value of all of the sources, the
--- second onNext event contains the second value of all of the sources, and so on.  onNext is called
--- a number of times equal to the number of values produced by the Observable that produces the
--- fewest number of values.
--- @param ... Observable - The Observables to zip.
---@return Observable
function Observable.Zip(...)
    local sources = util.Pack(...)
    local count = #sources

    return Observable.Create(function(observer)
        local values = {}
        local active = {}
        local subscriptions = {}
        for i = 1, count do
            values[i] = { n = 0 }
            active[i] = true
        end

        local function onNext(i)
            return function(value)
                table.insert(values[i], value)
                values[i].n = values[i].n + 1

                local ready = true
                for i = 1, count do
                    if values[i].n == 0 then
                        ready = false
                        break
                    end
                end

                if ready then
                    local payload = {}

                    for i = 1, count do
                        payload[i] = table.remove(values[i], 1)
                        values[i].n = values[i].n - 1
                    end

                    observer:OnNext(util.Unpack(payload))
                end
            end
        end

        local function onError(message)
            return observer:OnError(message)
        end

        local function onCompleted(i)
            return function()
                active[i] = nil
                if not next(active) or values[i].n == 0 then
                    return observer:OnCompleted()
                end
            end
        end

        for i = 1, count do
            subscriptions[i] = sources[i]:Subscribe(onNext(i), onError, onCompleted(i))
        end

        return Subscription.Create(function()
            for i = 1, count do
                if subscriptions[i] then subscriptions[i]:Unsubscribe() end
            end
        end)
    end)
end

--- Aliases
Observable.Wrap = Observable.Buffer
Observable['Repeat'] = Observable.Replicate
Observable.Where = Observable.Filter

--#endregion Operators

return Observable
