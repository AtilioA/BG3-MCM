EHandlers = {}

function EHandlers.OnLevelGameplayStarted(levelName, isEditorMode)
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

return EHandlers
