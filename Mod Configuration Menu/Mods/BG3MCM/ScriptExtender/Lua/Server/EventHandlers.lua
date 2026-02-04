EHandlers = {}

EHandlers.SFX_OPEN_MCM_WINDOW = "7151f51c-cc6c-723c-8dbd-ec3daa634b45"
EHandlers.SFX_CLOSE_MCM_WINDOW = "1b54367f-364a-5cb2-d151-052822622d0c"

local function warnAboutNPAKM()
    if LoadOrderHealthCheck and LoadOrderHealthCheck.ShouldWarnAboutNPAKM and LoadOrderHealthCheck:ShouldWarnAboutNPAKM() then
        local host = Osi.GetHostCharacter()
        if host and Osi.OpenMessageBox then
            local message = Ext.Loca.GetTranslatedString("h41e2dbf1773848eca2001fde456cca4d0156")
            MCMWarn(0, message)
            Osi.OpenMessageBox(host, message)
        end
    end
end

local function loadSettingsAndWarn()
    if MCMServer:HasSentInitialConfig() then
        MCMDebug(2, "Initial MCM config already sent; skipping redundant broadcast")
        return
    end

    MCMServer:LoadAndSendSettings()

    ModEventManager:IssueDeprecationWarning()
    VCTimer:OnTicks(4, warnAboutNPAKM)
end

function EHandlers.SavegameLoaded()
    loadSettingsAndWarn()
end

function EHandlers.CCStarted()
    loadSettingsAndWarn()
end

--- Handle client request for configs
--- Uses ChunkedNet to send large response back to client
---@param data table Request data (contains userID)
---@param userID number The user ID of the requesting client
---@return table Response with success status
function EHandlers.OnClientRequestConfigs(data, userID)
    MCMDebug(1, "Received MCM settings request from user: " .. tostring(userID))
    
    if not MCMAPI.mods or not MCMAPI.profiles then
        MCMServer:LoadAndSendSettings()
        return { success = true, message = "Loading configurations..." }
    else
        -- Use ChunkedNet to send the large payload back to the specific user
        local payloadTable = { userID = userID, mods = MCMAPI.mods, profiles = MCMAPI.profiles }
        ChunkedNet.SendTableToUser(userID, NetChannels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT, payloadTable)
        return { success = true, message = "Configurations sent via chunked transfer" }
    end
end

--- Handle client request to set a setting value
---@param data table Request data with settingId, value, modUUID
---@param userID number The user ID of the requesting client
---@return table Response with success status
function EHandlers.OnClientRequestSetSettingValue(data, userID)
    local settingId = data.settingId
    local value = data.value
    local modUUID = data.modUUID

    if not settingId or not modUUID then
        return { success = false, error = "Missing required fields: settingId and modUUID" }
    end

    if type(value) == "table" then
        MCMDebug(2, "Will set " .. settingId .. " to " .. Ext.Json.Stringify(value) .. " for mod " .. modUUID)
    else
        MCMDebug(1, "Will set " .. settingId .. " to " .. tostring(value) .. " for mod " .. modUUID)
    end

    local ok, err = pcall(function()
        MCMServer:SetSettingValue(settingId, value, modUUID)
    end)
    
    if not ok then
        MCMError(0, "Failed to set setting value: " .. tostring(err))
        return { success = false, error = tostring(err) }
    end
    
    return { success = true, data = { settingId = settingId, value = value, modUUID = modUUID } }
end

--- Handle client request to reset a setting value
---@param data table Request data with settingId, modUUID
---@param userID number The user ID of the requesting client
---@return table Response with success status
function EHandlers.OnClientRequestResetSettingValue(data, userID)
    local settingId = data.settingId
    local modUUID = data.modUUID

    if not settingId then
        return { success = false, error = "Missing required field: settingId" }
    end

    MCMDebug(1, "Will reset " .. settingId .. " for mod " .. modUUID)

    local ok, err = pcall(function()
        MCMServer:ResetSettingValue(settingId, modUUID)
    end)
    
    if not ok then
        MCMError(0, "Failed to reset setting value: " .. tostring(err))
        return { success = false, error = tostring(err) }
    end
    
    return { success = true, data = { settingId = settingId, modUUID = modUUID } }
end

-- function EHandlers.OnClientRequestProfiles(_)
--     MCMDebug(1, "Received profiles request")
--     MCMServer:SendProfiles()
-- end

--- Handle client request to set active profile
---@param data table Request data with profileName
---@param userID number The user ID of the requesting client
---@return table Response with success status
function EHandlers.OnClientRequestSetProfile(data, userID)
    local profileName = data.profileName

    if not profileName then
        return { success = false, error = "Missing required field: profileName" }
    end

    MCMDebug(1, "Will set profile to " .. profileName)

    local ok, result = pcall(function()
        return MCMServer:SetProfile(profileName)
    end)
    
    if not ok then
        MCMError(0, "Failed to set profile: " .. tostring(result))
        return { success = false, error = tostring(result) }
    end
    
    return { success = result, data = { profileName = profileName } }
end

--- Handle client request to create a new profile
---@param data table Request data with profileName
---@param userID number The user ID of the requesting client
---@return table Response with success status
function EHandlers.OnClientRequestCreateProfile(data, userID)
    local profileName = data.profileName

    if not profileName then
        return { success = false, error = "Missing required field: profileName" }
    end

    MCMDebug(1, "Will create profile " .. profileName)

    local ok, result = pcall(function()
        return MCMServer:CreateProfile(profileName)
    end)
    
    if not ok then
        MCMError(0, "Failed to create profile: " .. tostring(result))
        return { success = false, error = tostring(result) }
    end
    
    return { success = result, data = { profileName = profileName } }
end

--- Handle client request to delete a profile
---@param data table Request data with profileName
---@param userID number The user ID of the requesting client
---@return table Response with success status
function EHandlers.OnClientRequestDeleteProfile(data, userID)
    local profileName = data.profileName

    if not profileName then
        return { success = false, error = "Missing required field: profileName" }
    end

    MCMDebug(1, "Will delete profile " .. profileName)

    local ok, result = pcall(function()
        return MCMServer:DeleteProfile(profileName)
    end)
    
    if not ok then
        MCMError(0, "Failed to delete profile: " .. tostring(result))
        return { success = false, error = tostring(result) }
    end
    
    return { success = result, data = { profileName = profileName } }
end

--- Handle user opened window event (via mod event, not net channel)
---@param data table Event data with playSound flag
function EHandlers.OnUserOpenedWindow(data)
    if not data then
        MCMWarn(0, "Failed to parse payload data")
        return
    end

    if data.playSound and data.userId then
        MCMUtils:PlaySound(data.userId, EHandlers.SFX_OPEN_MCM_WINDOW)
    end
end

--- Handle user closed window event (via mod event, not net channel)
---@param data table Event data with playSound flag
function EHandlers.OnUserClosedWindow(data)
    if not data then
        MCMWarn(0, "Failed to parse payload data")
        return
    end

    if data.playSound and data.userId then
        MCMUtils:PlaySound(data.userId, EHandlers.SFX_CLOSE_MCM_WINDOW)
    end
end

-- Run tests if debug level is high enough
function EHandlers.OnSessionLoaded()
    if Config:getCfg().DEBUG.level > 2 then
        TestSuite.RunTests()
    end
end

local function showTroubleshootingNotification(userCharacter)
    Osi.OpenMessageBox(userCharacter, Ext.Loca.GetTranslatedString("h62488e121c3345bf81777731789205cd2154"))
end

local function updateNotificationStatus(userId, MCMModVars)
    -- TODO: Also check mcm_params file (implement this later on)
    MCMModVars.Notifications = MCMModVars.Notifications or {}
    MCMModVars.Notifications["MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION"] = MCMModVars.Notifications
        ["MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION"] or {}
    if not MCMModVars.Notifications["MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION"][tostring(userId)] then
        MCMModVars.Notifications["MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION"][tostring(userId)] = true
        MCMUtils:SyncModVars(ModuleUUID)
        return true
    end
    return false
end

--- Handle user spamming MCM button
---@param data table Request data
---@param userID number The user ID of the requesting client
---@return table Response with success status
function EHandlers.OnUserSpamMCMButton(data, userID)
    MCMDebug(1, "User is spamming MCM button; showing troubleshooting notification")
    
    local userCharacter = MCMUtils:GetUserCharacter(userID)
    if userCharacter then
        local MCMModVars = Ext.Vars.GetModVariables(ModuleUUID)
        if updateNotificationStatus(userID, MCMModVars) then
            showTroubleshootingNotification(userCharacter)
        end
        return { success = true }
    else
        MCMDebug(1, "Failed to show notification - userCharacter is nil")
        return { success = false, error = "User character not found" }
    end
end

--- Handle relay to clients (cross-context messaging)
---@param data table Request data with channel and payload
---@param userID number The user ID of the requesting client
---@return table Response with success status
function EHandlers.OnRelayToClients(data, userID)
    if not data or not data.channel or not data.payload then
        return { success = false, error = "Invalid relay data: missing channel or payload" }
    end
    
    -- Use NetChannel to broadcast to clients
    local targetChannel = NetChannels[data.channel]
    if targetChannel then
        targetChannel:Broadcast(data.payload)
        return { success = true }
    else
        MCMWarn(0, "Unknown channel for relay: " .. tostring(data.channel))
        return { success = false, error = "Unknown channel: " .. tostring(data.channel) }
    end
end

--- Handle emit on server (cross-context event emission)
---@param data table Request data with eventName and eventData
---@param userID number The user ID of the requesting client
---@return table Response with success status
function EHandlers.OnEmitOnServer(data, userID)
    if not data or not data.eventName then
        return { success = false, error = "Invalid emit data: missing eventName" }
    end
    
    local eventName = data.eventName
    local eventData = data.eventData

    MCMDebug(2, "Emitting event " .. eventName .. " on server as well.")

    local ok, err = pcall(function()
        if Ext.ModEvents['BG3MCM'] and Ext.ModEvents['BG3MCM'][eventName] then
            Ext.ModEvents['BG3MCM'][eventName]:Throw(eventData)
        else
            error("Event '" .. eventName .. "' not registered")
        end
    end)
    
    if not ok then
        MCMWarn(0, "Failed to emit event: " .. tostring(err))
        return { success = false, error = tostring(err) }
    end
    
    return { success = true }
end

return EHandlers
