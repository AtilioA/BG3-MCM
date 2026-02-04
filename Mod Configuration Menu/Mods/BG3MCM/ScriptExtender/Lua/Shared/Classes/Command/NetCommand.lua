--- @class NetCommand
--- Represents a (net) command that can be executed.
--- Modernized for NetChannel API - uses SetRequestHandler pattern
NetCommand = {}
NetCommand.__index = NetCommand

--- Creates a new NetCommand instance.
--- @param callback function The callback function to be executed when the command is executed.
--- @return NetCommand
function NetCommand:new(callback)
    local cmd = setmetatable({}, self)
    cmd.callback = callback
    return cmd
end

--- Executes the command.
--- Modernized signature for NetChannel: receives parsed data directly
--- @param data table The parsed data payload from the request.
--- @param peerId any The peer ID of the command.
--- @return table The response with { success = boolean, data = any, error = string? }
function NetCommand:execute(data, peerId)
    local ok, result = xpcall(function()
        return self.callback(data, peerId)
    end, function(err)
        MCMError(0, "NetCommand execution error: " .. tostring(err))
        return { success = false, error = tostring(err) }
    end)
    
    if not ok then
        return { success = false, error = tostring(result) }
    end
    
    -- Ensure standard response format
    if type(result) == "table" and result.success ~= nil then
        return result
    else
        return { success = true, data = result }
    end
end

return NetCommand
