-- Server-only operations extend the shared ModEventManager table.

--- Send a legacy net message to a specific user
---@param userID number
---@param channel string
---@param payload table|any
---@return boolean sent
function ModEventManager:SendLegacyNetMessageToUser(userID, channel, payload)
    if not userID or not channel then
        MCMWarn(0, "Cannot post legacy net message to user: missing userID or channel")
        return false
    end

    if payload == nil then
        payload = {}
    end

    local okPayload, payloadJson = pcall(Ext.Json.Stringify, payload)
    if not okPayload then
        MCMWarn(0, "Failed to serialize legacy user payload for channel '%s'", channel)
        return false
    end

    local ok = xpcall(function()
        Ext.ServerNet.PostMessageToUser(userID, channel, payloadJson)
    end, function(err)
        MCMWarn(0, "Error while posting legacy user net message: %s", err)
    end)

    return ok
end
