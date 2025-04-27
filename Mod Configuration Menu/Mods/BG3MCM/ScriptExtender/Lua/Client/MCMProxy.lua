--- MCMProxy ensures that mod settings can be managed and updated from the main menu if necessary, or from the server if the game is running.
---
---@class MCMProxy
MCMProxy = _Class:Create("MCMProxy", nil, {})

function MCMProxy.IsMainMenu()
    local gameState = Ext.Utils.GetGameState()
    return gameState == 'Menu'
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

function MCMProxy:InsertModMenuTab(modUUID, tabName, tabCallback)
    -- Handle initial state
    local disclaimerTab, disclaimerElement
    local function handleGameState(gameState)
        VCTimer:OnTicks(2, function()
            if gameState == "Menu" then
                MCMClientState.UIReady:Subscribe(function(ready)
                    if not ready then return end
                    -- Add temporary message to inform users that custom MCM tabs are not available in the main menu
                    if disclaimerTab or disclaimerElement then return end
                    disclaimerTab, disclaimerElement = DualPane:CreateTabWithDisclaimer(
                        modUUID, tabName, "h99e6c7f6eb9c43238ca27a89bb45b9690607"
                    )
                end)
            elseif gameState == "Running" then
                if disclaimerElement then
                    xpcall(function() disclaimerElement.Label = "" end, function() end)
                end
                MCMClientState.UIReady:Subscribe(function(ready)
                    if ready then
                        DualPane:InsertModTab(modUUID, tabName, tabCallback)
                    end
                end)
            end
        end)
    end

    handleGameState(Ext.Utils.GetGameState())

    Ext.Events.GameStateChanged:Subscribe(function(e)
        handleGameState(e.ToState)
    end)
end

function MCMProxy:GetSettingValue(settingId, modUUID)
    if MCMProxy.IsMainMenu() then
        return MCMAPI:GetSettingValue(settingId, modUUID)
    else
        return MCMClientState:GetClientStateValue(settingId, modUUID)
    end
end

function MCMProxy:SetSettingValue(settingId, value, modUUID, setUIValue)
    if MCMProxy.IsMainMenu() then
        -- Handle locally
        MCMAPI:SetSettingValue(settingId, value, modUUID)
        if setUIValue then setUIValue(value) end
    else
        -- Send to server
        Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE, Ext.Json.Stringify({
            modUUID = modUUID,
            settingId = settingId,
            value = value
        }))
        -- Check if server updated the setting
        ModEventManager:Subscribe(EventChannels.MCM_SETTING_SAVED, function(data)
            if data.modUUID ~= modUUID or data.settingId ~= settingId then return end
            if setUIValue then setUIValue(data.value) end
        end)
    end
end

function MCMProxy:ResetSettingValue(settingId, modUUID)
    if MCMProxy.IsMainMenu() then
        -- Handle locally
        MCMAPI:ResetSettingValue(settingId, modUUID)
        MCMClientState:SetClientStateValue(settingId, MCMAPI:GetSettingValue(settingId, modUUID), modUUID)
    else
        -- Send to server
        Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE, Ext.Json.Stringify({
            modUUID = modUUID,
            settingId = settingId
        }))
    end
end

function MCMProxy:RegisterMCMKeybindings()
    InputCallbackManager.RegisterKeybinding(ModuleUUID, "toggle_mcm_keybinding",
        function() IMGUIAPI:ToggleMCMWindow(true) end)
    InputCallbackManager.RegisterKeybinding(ModuleUUID, "reset_lua", function() Ext.Debug.Reset() end)
    InputCallbackManager.RegisterKeybinding(ModuleUUID, "close_mcm_keybinding",
        function() IMGUIAPI:CloseMCMWindow(true) end)
    InputCallbackManager.RegisterKeybinding(ModuleUUID, "toggle_mcm_sidebar_keybinding",
        function() IMGUIAPI:ToggleMCMSidebar() end)
end
