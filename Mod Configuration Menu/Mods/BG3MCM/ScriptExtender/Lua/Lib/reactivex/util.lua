local util = {}

util.Pack = table.pack or function(...) return { n = select('#', ...), ... } end
---@diagnostic disable-next-line: deprecated
util.Unpack = table.unpack or unpack
util.Eq = function(x, y) return x == y end
util.Noop = function() end
util.Identity = function(x) return x end
util.Constant = function(x) return function() return x end end
util.IsA = function(object, classOrClassName)
    if type(object) == 'table'
        and type(getmetatable(object)) == 'table'
    then
        if getmetatable(object).__index == classOrClassName
            or tostring(object) == classOrClassName
        then
            -- object is an instance of that class
            return true
        elseif type(object.___isa) == 'table' then
            for _, v in ipairs(object.___isa) do
                if v == classOrClassName
                    or tostring(v) == classOrClassName
                then
                    -- object is an instance of a subclass of that class
                    -- or it implements interface of that class (at least it says so)
                    return true
                end
            end
        elseif type(object.___isa) == 'function' then
            -- object says whether it implements that class
            return object:___isa(classOrClassName)
        end
    end

    return false
end
util.HasValue = function(tab, value)
    for _, v in ipairs(tab) do
        if v == value then
            return true
        end
    end

    return false
end
util.IsCallable = function(thing)
    return type(thing) == 'function'
        or (
            type(thing) == 'table'
            and type(getmetatable(thing)) == 'table'
            and type(getmetatable(thing).__call) == 'function'
        )
end
util.TryWithObserver = function(observer, fn, ...)
    local success, result = pcall(fn, ...)
    if not success then
        observer:OnError(result)
    end
    return success, result
end

return util
