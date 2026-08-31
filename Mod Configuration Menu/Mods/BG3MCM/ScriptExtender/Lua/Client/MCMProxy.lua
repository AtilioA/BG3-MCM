--- MCMProxy ensures that mod settings can be managed and updated from the main menu if necessary, or from the server if the game is running.

---@class MCMProxy
MCMProxy = _Class:Create("MCMProxy", nil, {
    PendingSettingWrites = {},
})

---Check if the game is in the main menu
---@return boolean
function MCMProxy.IsMainMenu()
    return Ext.Utils.GetGameState() == Ext.Enums.ClientGameState["Menu"]
end

--- Load mod configurations
---@param self MCMProxy
function MCMProxy:LoadConfigs()
    local function loadConfigs()
        local _mods = ModConfig:GetSettings()
        local _profiles = ModConfig:GetProfiles()
    end

    if self:IsMainMenu() then
        loadConfigs()
    else
        NetChannels.MCM_CLIENT_REQUEST_CONFIGS:RequestToServer(
            { message = "Requesting MCM settings from server." },
            function(response)
                if response.success then
                    MCMDebug(1, "Successfully requested configs from server: %s", response.message or "")
                else
                    MCMWarn(0, "Failed to request configs from server: %s", response.error or "Unknown error")
                end
            end
        )
    end
end

--- Insert a mod menu tab
---@param self MCMProxy
---@param modUUID string The UUID of the mod
---@param tabName string The name of the tab to be inserted
---@param tabCallback function The callback function to create the tab
---@param skipDisclaimer? boolean If true, skip the disclaimer and render tab content immediately (default: false)
---@return nil
function MCMProxy:InsertModMenuTab(modUUID, tabName, tabCallback, skipDisclaimer)
    local disclaimerTab, disclaimerElement
    local inserted = false
    local function handleGameState(gameState)
        if inserted then return end
        -- This timer is a workaround. Ideally, we should be able to use this value directly. May refactor this if we get a way to query the game state directly.
        VCTimer:OnTicks(2, function()
            if gameState == "Menu" then
                -- We're in the main menu
                MCMClientState.UIReady:Subscribe(function(ready)
                    if not ready then
                        return
                    end

                    if skipDisclaimer == true then
                        DualPane:InsertModTab(modUUID, tabName, tabCallback, skipDisclaimer)
                    else
                        -- Add temporary message to inform users that custom MCM tabs are not available in the main menu
                        if disclaimerTab or disclaimerElement then return end
                        disclaimerTab, disclaimerElement = DualPane:CreateTabWithDisclaimer(
                            modUUID, tabName, "h99e6c7f6eb9c43238ca27a89bb45b9690607"
                        )
                    end
                end)
            elseif gameState == "Running" then
                if disclaimerElement then
                    xpcall(function() disclaimerElement.Label = "" end, function() end)
                end

                MCMClientState.UIReady:Subscribe(function(ready)
                    if ready then
                        DualPane:InsertModTab(modUUID, tabName, tabCallback, skipDisclaimer)
                        inserted = true
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

--- Get a setting value
---@param settingId string The ID of the setting to get
---@param modUUID string The UUID of the mod to get the setting for
---@return any - The value of the setting
function MCMProxy:GetSettingValue(settingId, modUUID)
    if MCMProxy.IsMainMenu() then
        return MCMAPI:GetSettingValue(settingId, modUUID)
    else
        return MCMClientState:GetClientStateValue(settingId, modUUID)
    end
end

--- Update enum choices at runtime.
---@param settingId string The ID of the enum setting to update
---@param choices string[] The choices to expose
---@param choicesHandles? string[] Optional parallel array of localization handles
---@param modUUID string The UUID of the mod that owns the setting
---@return boolean success
function MCMProxy:SetEnumChoices(settingId, choices, choicesHandles, modUUID)
    if self:IsMainMenu() then
        return MCMAPI:SetEnumChoices(settingId, choices, choicesHandles, modUUID, true)
    end

    NetChannels.MCM_CLIENT_REQUEST_SET_ENUM_CHOICES:RequestToServer(
        {
            modUUID = modUUID,
            settingId = settingId,
            choices = choices,
            choicesHandles = choicesHandles
        },
        function(response)
            if response.success then
                MCMDebug(1, "Successfully updated enum choices for setting %s on server", settingId)
            else
                MCMWarn(0, "Failed to update enum choices for setting %s: %s", settingId,
                    response.error or "Unknown error")
            end
        end
    )

    return true
end

---@alias SettingWriteState "saved"|"queued"|"rejected"

---@class SettingWriteReceipt
---@field accepted boolean Whether the write was accepted locally or queued for the server
---@field state SettingWriteState The immediate state of the write
---@field value? any The submitted value
---@field error? string The rejection reason when available

--- Set a setting value through the local or server adapter.
---@param settingId string The ID of the setting to set
---@param value any The value to set the setting to
---@param modUUID string The UUID of the mod to set the setting for
---@param setUIValue fun(value: any)|nil A function to reconcile the UI with the authoritative value
---@param shouldEmitEvent? boolean Whether to emit the setting saved event
---@return SettingWriteReceipt receipt The immediate acceptance state
function MCMProxy:SetSettingValue(settingId, value, modUUID, setUIValue, shouldEmitEvent)
    if self:IsMainMenu() then
        local success = MCMAPI:SetSettingValue(settingId, value, modUUID, shouldEmitEvent)
        if success and setUIValue then
            setUIValue(value)
        end
        if success then
            return { accepted = true, state = "saved", value = value }
        end
        return { accepted = false, state = "rejected", error = "Setting value was rejected" }
    end

    -- Remote writes are fire-and-forget at this layer: the authoritative value
    -- arrives later through the MCM_INTERNAL_SETTING_SAVED broadcast, which is
    -- the only source used for rollback. The request response is not authoritative
    -- (it can arrive after a newer accepted or profile value), so this callback
    -- only logs and clears pending state. It never reconciles UI or emits rollback.
    local requestKey = modUUID .. ":" .. settingId
    local pendingWrite = {
        value = value
    }
    self.PendingSettingWrites[requestKey] = pendingWrite

    NetChannels.MCM_CLIENT_REQUEST_SET_SETTING_VALUE:RequestToServer(
        {
            modUUID = modUUID,
            settingId = settingId,
            value = value
        },
        function(response)
            if self.PendingSettingWrites[requestKey] ~= pendingWrite then
                return
            end
            self.PendingSettingWrites[requestKey] = nil

            if response and response.success then
                MCMDebug(1, "Successfully set setting %s on server", settingId)
                return
            end

            MCMWarn(0, "Failed to set setting %s: %s", settingId,
                response and response.error or "Unknown error")
        end
    )

    return { accepted = true, state = "queued", value = value }
end

--- Reset a setting value
---@param settingId string The ID of the setting to reset
---@param modUUID string The UUID of the mod to reset the setting for
function MCMProxy:ResetSettingValue(settingId, modUUID)
    if MCMProxy.IsMainMenu() then
        -- Handle locally
        MCMAPI:ResetSettingValue(settingId, modUUID)
        MCMClientState:SetClientStateValue(settingId, MCMAPI:GetSettingValue(settingId, modUUID), modUUID)
    else
        NetChannels.MCM_CLIENT_REQUEST_RESET_SETTING_VALUE:RequestToServer(
            {
                modUUID = modUUID,
                settingId = settingId
            },
            function(response)
                if response.success then
                    MCMDebug(1, "Successfully reset setting %s on server", settingId)
                else
                    MCMWarn(0, "Failed to reset setting %s: %s", settingId, response.error or "Unknown error")
                end
            end
        )
    end
end

--- Create a new profile
---@param profileName string The name of the profile to create
function MCMProxy:CreateProfile(profileName)
    if MCMProxy.IsMainMenu() then
        -- Handle locally
        MCMAPI:CreateProfile(profileName)
    else
        NetChannels.MCM_CLIENT_REQUEST_CREATE_PROFILE:RequestToServer(
            { profileName = profileName },
            function(response)
                if response.success then
                    MCMDebug(1, "Successfully created profile %s", profileName)
                else
                    MCMWarn(0, "Failed to create profile %s: %s", profileName, response.error or "Unknown error")
                end
            end
        )
    end
end

--- Set the active profile
---@param profileName string The name of the profile to set
function MCMProxy:SetProfile(profileName)
    if MCMProxy.IsMainMenu() then
        -- Handle locally
        MCMAPI:SetProfile(profileName)
    else
        NetChannels.MCM_CLIENT_REQUEST_SET_PROFILE:RequestToServer(
            { profileName = profileName },
            function(response)
                if response.success then
                    MCMDebug(1, "Successfully set profile to %s", profileName)
                else
                    MCMWarn(0, "Failed to set profile to %s: %s", profileName, response.error or "Unknown error")
                end
            end
        )
    end
end

--- Delete a profile
---@param profileName string The name of the profile to delete
function MCMProxy:DeleteProfile(profileName)
    if MCMProxy.IsMainMenu() then
        -- Handle locally
        MCMAPI:DeleteProfile(profileName)
    else
        NetChannels.MCM_CLIENT_REQUEST_DELETE_PROFILE:RequestToServer(
            { profileName = profileName },
            function(response)
                if response.success then
                    MCMDebug(1, "Successfully deleted profile %s", profileName)
                else
                    MCMWarn(0, "Failed to delete profile %s: %s", profileName, response.error or "Unknown error")
                end
            end
        )
    end
end

function MCMProxy:RegisterMCMKeybindings()
    InputCallbackManager.RegisterKeybinding(ModuleUUID, "toggle_mcm_keybinding",
        function() IMGUIAPI:ToggleMCMWindow(true) end)
    InputCallbackManager.RegisterKeybinding(ModuleUUID, "reset_lua_both", function() Ext.Debug.Reset() end)
    InputCallbackManager.RegisterKeybinding(ModuleUUID, "reset_lua_client", function() Ext.Debug.Reset(false, true) end)
    InputCallbackManager.RegisterKeybinding(ModuleUUID, "reset_lua_server", function() Ext.Debug.Reset(true, false) end)
    InputCallbackManager.RegisterKeybinding(ModuleUUID, "close_mcm_keybinding",
        function() IMGUIAPI:CloseMCMWindow(true) end)
    InputCallbackManager.RegisterKeybinding(ModuleUUID, "toggle_mcm_sidebar_keybinding",
        function() IMGUIAPI:ToggleMCMSidebar() end)

    -- MCMAPI:SetEventButtonDisabled(ModuleUUID, "EventButtonExample2", true, "Disabled via API")
    -- MCMAPI:SetEventButtonDisabled(ModuleUUID, "EventButtonExample", true, "Disabled via API too")
end
