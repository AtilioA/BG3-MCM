Fallback = {}

--- Return `default` if `val` is nil, otherwise return `val`.
---@param val unknown
---@param default unknown
---@return unknown
function Fallback.Value(val, default)
    if val == nil then
        return default
    end
    return val
end

return Fallback
