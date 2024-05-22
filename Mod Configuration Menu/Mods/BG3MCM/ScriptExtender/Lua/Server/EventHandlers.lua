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

function EHandlers.OnClientRequestSetSettingValue(_, payload)
    local payload = Ext.Json.Parse(payload)
    local settingId = payload.settingId
    local value = payload.value
    local modGUID = payload.modGUID

    if type(value) == "table" then
        MCMDebug(2, "Will set " .. settingId .. " to " .. Ext.Json.Stringify(value) .. " for mod " .. modGUID)
    else
        MCMDebug(1, "Will set " .. settingId .. " to " .. tostring(value) .. " for mod " .. modGUID)
    end

    MCMAPI:SetSettingValue(settingId, value, modGUID, true)
end

function EHandlers.OnClientRequestResetSettingValue(_, payload)
    local payload = Ext.Json.Parse(payload)
    local settingId = payload.settingId
    local modGUID = payload.modGUID

    MCMDebug(1, "Will reset " .. settingId .. " for mod " .. modGUID)
    MCMAPI:ResetSettingValue(settingId, modGUID, true)
end

function EHandlers.OnClientRequestSetProfile(_, payload)
    local payload = Ext.Json.Parse(payload)
    local profileName = payload.profileName

    MCMDebug(1, "Will set profile to " .. profileName)
    MCMAPI:SetProfile(profileName)
end

function EHandlers.OnUserOpenedWindow(_)
    MCMUtils:PlaySound(EHandlers.SFX_OPEN_MCM_WINDOW)
end

function EHandlers.OnUserClosedWindow(_)
    MCMUtils:PlaySound(EHandlers.SFX_CLOSE_MCM_WINDOW)
end

return EHandlers
