MCMProxy = {}

MCMProxy.GameState = 'Menu'

function MCMProxy.IsMainMenu()
    if Ext.Net.IsHost then
        return Ext.Net.IsHost()
    end

    -- Old fallback since it's already here
    local gameState = MCMProxy.GameState

    if gameState == 'Menu' then
        return true
    end

    return false
end

-- TODO: add temporary message to inform users that custom MCM tabs are not available in the main menu
function MCMProxy:InsertModMenuTab(modGUID, tabName, tabCallback)
    -- FrameManager:updateModDescriptionTooltip(modGUID, "Some functionality from this mod requires a save to be loaded first.")

    if MCMProxy.IsMainMenu() or not
        FrameManager:GetGroup(modGUID) then
        -- local function addTempTextMainMenu(tabHeader)
        --     local tempTextDisclaimer = Ext.Loca.GetTranslatedString("h99e6c7f6eb9c43238ca27a89bb45b9690607")
        --     addTempText = tabHeader:AddText(tempTextDisclaimer)
        --     addTempText:SetColor("Text", Color.NormalizedRGBA(255, 55, 55, 1))
        -- end

        Ext.RegisterNetListener(Channels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT, function()
            FrameManager:InsertModTab(modGUID, tabName, tabCallback)
        end)
    else
        FrameManager:InsertModTab(modGUID, tabName, tabCallback)
    end
end

function MCMProxy:SetSettingValue(settingId, value, modGUID, setUIValue)
    if MCMProxy.IsMainMenu() then
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
    if MCMProxy.IsMainMenu() then
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
