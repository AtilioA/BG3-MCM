-- Authorized NetCommand interface
---@class AuthorizedCommand : NetCommand
AuthorizedNetCommand = setmetatable({}, { __index = NetCommand })
AuthorizedNetCommand.__index = AuthorizedNetCommand

--- Creates a new AuthorizedCommand instance.
---@param callback function The callback function to be executed.
---@return AuthorizedCommand The new AuthorizedCommand instance.
function AuthorizedNetCommand:new(callback)
    local cmd = setmetatable(NetCommand:new(callback), self)
    return cmd
end

--- Checks if the user is authorized to execute the command.
---@param userId number The user ID.
---@return boolean True if the user is authorized, false otherwise.
function AuthorizedNetCommand:IsUserAuthorized(userId)
    local onlyAllowHost = MCMAPI:GetSettingValue("host-only_mode", ModuleUUID)

    if not onlyAllowHost then
        MCMDebug(2, "Host-only mode is disabled. All users, including guests, are authorized to send requests.")
        return true
    end

    local isHost = MCMUtils:IsUserHost(userId)
    if isHost then
        MCMDebug(2, "Host user " .. Osi.GetUserName(userId) .. " is authorized to send requests.")
        return true
    end

    return false
end

--- Executes the command if the user is authorized.
---@param channel string The communication channel.
---@param payload any The data payload.
---@param peerId number The peer ID of the user.
function AuthorizedNetCommand:execute(channel, payload, peerId)
    local userId = MCMUtils:PeerToUserID(peerId)
    if not self:IsUserAuthorized(userId) then
        MCMWarn(0,
            "Unauthorized user " ..
            Osi.GetUserName(userId) .. " tried to send a request. Only the host can send requests in host-only mode.")
        return
    else
        self.callback(channel, payload, userId)
    end
end
