MCMProxy = {}

MCMProxy.GameState = 'Menu'

local function isMainMenu()
    local gameState = MCMProxy.GameState

    if gameState == 'Menu' then
        return true
    end

    -- if gameState ~= "LoadSession" and gameState ~= "LoadLevel" and gameState ~= "SwapLevel" and
    --     gameState ~= "StopLoading" and gameState ~= "PrepareRunning" and gameState ~= "Running" then
    --     return false
    -- end

    return false
end

function MCMProxy:SetSettingValue(settingId, value, modGUID, setUIValue)
    if isMainMenu() then
        -- Handle locally
        MCMAPI:SetSettingValue(settingId, value, modGUID)
        if setUIValue then
            setUIValue(value)
        end
    else
        -- Send to server
        Ext.Net.PostMessageToServer(Channels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE, Ext.Json.Stringify({
            modGUID = modGUID,
            settingId = settingId,
            value = value
        }))
        Ext.RegisterNetListener(Channels.MCM_SETTING_UPDATED, function(_, payload)
            local data = Ext.Json.Parse(payload)
            if data.modGUID == modGUID and data.settingId == settingId then
                if setUIValue then
                    setUIValue(data.value)
                end
            end
        end)
    end
end

function MCMProxy:ResetSettingValue(settingId, modGUID)
    if isMainMenu() then
        -- Handle locally
        MCMAPI:ResetSettingValue(settingId, modGUID)
        MCMClientState:SetClientStateValue(settingId, MCMAPI:GetSettingValue(settingId, modGUID), modGUID)
    else
        -- Send to server
        Ext.Net.PostMessageToServer(Channels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE, Ext.Json.Stringify({
            modGUID = modGUID,
            settingId = settingId
        }))
    end
end

return MCMProxy
