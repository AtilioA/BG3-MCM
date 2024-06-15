EHandlers = {}

EHandlers.SFX_OPEN_MCM_WINDOW = "7151f51c-cc6c-723c-8dbd-ec3daa634b45"
EHandlers.SFX_CLOSE_MCM_WINDOW = "1b54367f-364a-5cb2-d151-052822622d0c"

function EHandlers.OnLevelGameplayStarted(levelName, isEditorMode)
    MCMDebug(2, "Level " .. levelName .. " started")
    MCMAPI:LoadAndSendSettings()
end

function EHandlers.OnClientRequestConfigs(_)
    MCMDebug(1, "Received MCM settings request")
    MCMAPI:LoadAndSendSettings()
end

function EHandlers.OnClientRequestSetSettingValue(_, payload, peerId)
    local parsedPayload = Ext.Json.Parse(payload)
    local settingId = parsedPayload.settingId
    local value = parsedPayload.value
    local modGUID = parsedPayload.modGUID

    if type(value) == "table" then
        MCMDebug(2, "Will set " .. settingId .. " to " .. Ext.Json.Stringify(value) .. " for mod " .. modGUID)
    else
        MCMDebug(1, "Will set " .. settingId .. " to " .. tostring(value) .. " for mod " .. modGUID)
    end

    MCMAPI:SetSettingValue(settingId, value, modGUID, true)
end

function EHandlers.OnClientRequestResetSettingValue(_, payload, peerId)
    local parsedPayload = Ext.Json.Parse(payload)
    local settingId = parsedPayload.settingId
    local modGUID = parsedPayload.modGUID

    MCMDebug(1, "Will reset " .. settingId .. " for mod " .. modGUID)
    MCMAPI:ResetSettingValue(settingId, modGUID, true)
end

-- function EHandlers.OnClientRequestProfiles(_)
--     MCMDebug(1, "Received profiles request")
--     MCMAPI:SendProfiles()
-- end

function EHandlers.OnClientRequestSetProfile(_, payload, peerId)
    local parsedPayload = Ext.Json.Parse(payload)
    local profileName = parsedPayload.profileName

    MCMDebug(1, "Will set profile to " .. profileName)
    MCMAPI:SetProfile(profileName)
end

function EHandlers.OnClientRequestCreateProfile(_, payload, peerId)
    local parsedPayload = Ext.Json.Parse(payload)
    local profileName = parsedPayload.profileName

    MCMDebug(1, "Will create profile " .. profileName)
    MCMAPI:CreateProfile(profileName)
end

function EHandlers.OnClientRequestDeleteProfile(_, payload, peerId)
    local parsedPayload = Ext.Json.Parse(payload)
    local profileName = parsedPayload.profileName

    MCMDebug(1, "Will delete profile " .. profileName)
    MCMAPI:DeleteProfile(profileName)
end

function EHandlers.OnUserOpenedWindow(_, payload, peerId)
    MCMUtils:PlaySound(userId, EHandlers.SFX_OPEN_MCM_WINDOW)
end

function EHandlers.OnUserClosedWindow(_, payload, peerId)
    MCMUtils:PlaySound(userId, EHandlers.SFX_CLOSE_MCM_WINDOW)
end

-- Run tests if debug level is high enough
function EHandlers.OnSessionLoaded()
    if Config:getCfg().DEBUG.level > 2 then
        TestSuite.RunTests()
    end
end

local function showTroubleshootingNotification(userCharacter)
    -- TODO: use loca
    Osi.OpenMessageBox(userCharacter,
        "If you don't see the MCM window, please see the mod page for troubleshooting steps.\nThis is usually caused by third-party overlays or by alt-tabbing before reaching the main menu.")
end

local function updateNotificationStatus(userId, MCMModVars)
    -- TODO: Also check mcm_params file (implement this later on)
    MCMModVars.Notifications = MCMModVars.Notifications or {}
    MCMModVars.Notifications["MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION"] = MCMModVars.Notifications["MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION"] or {}
    if not MCMModVars.Notifications["MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION"][tostring(userId)] then
        MCMModVars.Notifications["MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION"][tostring(userId)] = true
        MCMUtils:SyncModVars(ModuleUUID)
        return true
    end
    return false
end

function EHandlers.OnUserSpamMCMButton(_, payload, peerId)
    MCMDebug(1, "User is spamming the MCM button... showing troubleshooting notification")
    local userId = MCMUtils:PeerToUserID(peerId)
    local userCharacter = MCMUtils:GetUserCharacter(userId)
    if userCharacter then
        local MCMModVars = Ext.Vars.GetModVariables(ModuleUUID)
        if updateNotificationStatus(userId, MCMModVars) then
            showTroubleshootingNotification(userCharacter)
        end
    else
        MCMDebug(1, "Failed to show notification - userCharacter is nil")
    end
end

return EHandlers
