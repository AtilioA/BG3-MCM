--- MCMProxy ensures that mod settings can be managed and updated from the main menu if necessary, or from the server if the game is running.
---
---@class MCMProxy
---@field GameState string The current game state. Might be used to determine if the game is in the main menu.
---@field GameStateSubject any Subject that emits game state changes
MCMProxy = _Class:Create("MCMProxy", nil, {
    GameState = Ext.Net.IsHost() and "Running" or "Menu",
    GameStateSubject = nil
})

local RX = Ext.Require("Lib/reactivex/_init.lua")

-- Initialize the reactive game state management
function MCMProxy:Initialize()
    self.GameStateSubject = RX.BehaviorSubject.Create(self.GameState)

    Ext.Events.GameStateChanged:Subscribe(function(e)
        MCMProxy.GameState = e.ToState

        -- Emit the state change through our reactive subject
        if self.GameStateSubject then
            self.GameStateSubject:OnNext(MCMProxy.GameState)
        end

        MCMDebug(1, "GameState changed to " .. tostring(MCMProxy.GameState))
    end)
end

function MCMProxy.IsMainMenu()
    local gameState = MCMProxy.GameState

    if not gameState and Ext.Net.IsHost then
        return not Ext.Net.IsHost()
    end

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

function MCMProxy:InsertModMenuTab(modUUID, tabName, tabCallback)
    if not self.GameStateSubject then
        self:Initialize()
    end

    -- Subscribe to game state changes to handle tab insertion appropriately
    local disclaimerTab = nil
    local subscription = nil
    subscription = self.GameStateSubject:Subscribe(function(gameState)
        -- This timer is a workaround. Ideally, we should be able to use this value directly. May refactor this if we get a way to query the game state directly.
        VCTimer:OnTicks(2, function()
            if gameState == "Menu" then
                -- We're in the main menu
                MCMClientState.UIReady:Subscribe(function(ready)
                    if not ready then
                        return
                    end

                    -- Add temporary message to inform users that custom MCM tabs are not available in the main menu
                    if disclaimerTab then return end
                    disclaimerTab = DualPane:CreateTabWithDisclaimer(
                        modUUID,
                        tabName,
                        "h99e6c7f6eb9c43238ca27a89bb45b9690607"
                    )
                end)
            elseif gameState == "Running" then
                if disclaimerTab then
                    xpcall(function() disclaimerTab:Destroy() end, function(_err) end)
                end

                MCMClientState.UIReady:Subscribe(function(ready)
                    if ready and subscription and not subscription._unsubscribed then
                        DualPane:InsertModTab(modUUID, tabName, tabCallback)
                        subscription = nil
                    end
                end)
            end
        end)
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
        if setUIValue then
            setUIValue(value)
        end
    else
        -- Send to server
        Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE, Ext.Json.Stringify({
            modUUID = modUUID,
            settingId = settingId,
            value = value
        }))
        -- Check if server updated the setting
        ModEventManager:Subscribe(EventChannels.MCM_SETTING_SAVED, function(data)
            if data.modUUID ~= modUUID or data.settingId ~= settingId then
                return
            end

            if setUIValue then
                setUIValue(data.value)
            end
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

-- Initialize the proxy when the module is loaded
MCMProxy:Initialize()
