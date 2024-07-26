MCMProxy = {}

local function isMainMenu()
    -- TODO: Implement logic to determine if we're in the main menu
    -- This might involve checking game state or other indicators
    -- For now, we'll use a placeholder
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
