Fallback = {}

--- Return `default` if `val` is nil, otherwise return `val`.
-- @param val any
-- @param default any
-- @return any
function Fallback.Value(val, default)
    if val == nil then
        return default
    end
    return val
end

return Fallback
