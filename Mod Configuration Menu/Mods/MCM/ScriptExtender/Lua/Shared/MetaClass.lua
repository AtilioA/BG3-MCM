---@class MetaClass
---@field private _ClassName string
_MetaClass = {
    _ClassName = "VolitionCabinetMetaClass",
}
---@private
_MetaClass.__index = _MetaClass

local _Index = {}
local _DebugMetaTable = {
    __index = function(t, k)
        Ext.Utils.Print(string.format("Accessing key '%s' from table-class: '%s' '%s'", k, t[_Index],
            _Class:GetClass(t[_Index]) ~= nil and _Class:GetClass(t[_Index])._ClassName or "N/A"))
        return t[_Index][k]
    end,
    __newindex = function(t, k, v)
        Ext.Utils.Print(string.format("Writing key-value '%s' '%s' to table-class: '%s' '%s'", k, v, t[_Index],
            _Class:GetClass(t[_Index]) ~= nil and _Class:GetClass(t[_Index])._ClassName or "N/A"))
        t[_Index][k] = v
    end
}

--- Creates a new instance of a class, initializing it with the provided parameters.
--- @generic T
--- @param class T -- The class table.
--- @param o any -- The initial set of parameters for the new instance.
--- @return T -- The new instance.
function _MetaClass.New(class, o)
    o = o or {}
    setmetatable(o, class)
    class.__index = class

    -- if class.Init then
    --     o:Init()
    -- end

    return o
end

function _MetaClass:Init()
end

--- Set the return to the original object, e.g. someObj = someObj:_Debug()
---@private
---@nodiscard
---@generic T
---@param object T
---@return T
function _MetaClass._Debug(object)
    local proxy = {}
    proxy[_Index] = object
    setmetatable(proxy, _DebugMetaTable)
    return proxy
end

---@class _Class
---@field Classes table<string, table>
_Class = {
    Classes = {}
}

---Gets the class object of an object or class descended from _MetaClass
---@param object string|table
---@return table|nil
function _Class:GetClass(object)
    local className
    if type(object) == "table" then
        className = object._ClassName
    elseif type(object) == "string" then
        className = object
    end

    return self.Classes[className]
end

---@param object table
---@return string|nil
function _Class:GetClassName(object)
    return object._ClassName
end

---Creates a new class with a given name
---@generic T
---@param class `T` Name of new class
---@param parentClass? string|table Can be the name of a parent class or the class itself
---@param initial? table Initializing table for the class
---@return T
function _Class:Create(class, parentClass, initial)
    local newClass = _Class.Classes[class]
    if newClass == nil then
        newClass = initial or {}
        newClass._ClassName = class
        local mt = parentClass ~= nil and self:GetClass(parentClass) or _MetaClass
        setmetatable(newClass, mt)
        newClass.__index = newClass
        _Class.Classes[class] = newClass
    end

    return newClass
end
