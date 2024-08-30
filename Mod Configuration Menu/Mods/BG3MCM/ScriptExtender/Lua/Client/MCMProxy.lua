--- MCMProxy ensures that mod settings can be managed and updated from the main menu if necessary, or from the server if the game is running.
---
---@class MCMProxy
---@field GameState string The current game state. Might be used to determine if the game is in the main menu.
MCMProxy = _Class:Create("MCMProxy", nil, {
    GameState = 'Menu'
})

function MCMProxy.IsMainMenu()
    if Ext.Net.IsHost then
        return not Ext.Net.IsHost()
    end

    -- Old fallback since it's already here
    local gameState = MCMProxy.GameState

    if gameState == 'Menu' then
        return true
    end

    return false
end

function MCMProxy:LoadConfigs()
    local function loadConfigs()
        self.mods = ModConfig:GetSettings()
        self.profiles = ModConfig:GetProfiles()
    end
    
    if MCMProxy.IsMainMenu() then
        loadConfigs()
    else
        Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_CONFIGS, Ext.Json.Stringify({
            message = "Requesting MCM settings from server."
        }))
    end
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

        Ext.RegisterNetListener(NetChannels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT, function()
            FrameManager:InsertModTab(modGUID, tabName, tabCallback)
        end)
    else
        FrameManager:InsertModTab(modGUID, tabName, tabCallback)
    end
end

function MCMProxy:GetSettingValue(settingId, modGUID)
    if MCMProxy.IsMainMenu() then
        return MCMAPI:GetSettingValue(settingId, modGUID)
    else
        return MCMClientState:GetClientStateValue(settingId, modGUID)
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
        Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE, Ext.Json.Stringify({
            modGUID = modGUID,
            settingId = settingId,
            value = value
        }))
        -- Check if server updated the setting
        ModEventManager:Subscribe(EventChannels.MCM_SETTING_UPDATED, function(data)
            if data.modGUID ~= modGUID or data.settingId ~= settingId then
                return
            end

            if setUIValue then
                setUIValue(data.value)
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
        Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE, Ext.Json.Stringify({
            modGUID = modGUID,
            settingId = settingId
        }))
    end
end
