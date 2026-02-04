local _hasReceivedConfigPayload = nil

local function invalidateConfigPayloadCache()
    _hasReceivedConfigPayload = nil
end

local function handleStartKey()
    Noesis:MonitorMCMGameMenuButtonPress(true)
end

local function handleEscapeKey()
    Noesis:MonitorMCMGameMenuButtonPress(false)
end

local function handleKeyInput(e)
    if e.Event == "KeyDown" and e.Repeat == false then
        if e.Key == "ESCAPE" then
            handleEscapeKey()
            return
        end

        return
    end
end

local function handleCloseMCMKey()
    IMGUIAPI:CloseMCMWindow(true)
end

local function handleControllerInput(e)
    -- NOTE: Hardcoded close MCM key
    if e.Event == "KeyDown" and e.Pressed then
        -- Handle Start button for menu navigation
        if e.Button == "Start" then
            handleStartKey()
            handleCloseMCMKey()
            return
        end

        -- If MCM window is open, let the GamepadInputHandler handle most inputs
        if IMGUIAPI:IsMCMWindowOpen() then
            -- Allow Back, LeftShoulder, and RightShoulder to be handled by GamepadInputHandler
            if e.Button == "Back" or e.Button == "LeftShoulder" or e.Button == "RightShoulder" then
                return
            end

            -- For other buttons, prevent default action to avoid interfering with MCM UI
            e:PreventAction()
        end

        return
    end
end

--- SECTION: Ext events
Ext.Events.GameStateChanged:Subscribe(function(e)
    if e.ToState == Ext.Enums.ClientGameState["Menu"] then
        invalidateConfigPayloadCache()
        InitClientMCM()
    end
end)

Ext.Events.KeyInput:Subscribe(handleKeyInput)
Ext.Events.ControllerButtonInput:Subscribe(handleControllerInput)

-- Ext.Events.MouseButtonInput:Subscribe(function(e)
--     _D(e)
--     if e.Pressed then
--         _D(e)
--         -- Handle mouse button input here
--         -- Example: Check which button was pressed and its position
--         if e.Button == 1 then -- Left mouse button
--             print("Left mouse button pressed at: (" .. e.X .. ", " .. e.Y .. ")")
--         elseif e.Button == 2 then -- Right mouse button
--             print("Right mouse button pressed at: (" .. e.X .. ", " .. e.Y .. ")")
--         end
--     end
-- end)

-- -- Handle controller axis input
-- Ext.Events.ControllerAxisInput:Subscribe(function(e)

--     -- _D(e)
--     -- Handle controller axis input here
--     -- print("Controller axis " .. e.Axis .. " moved with value: " .. e.Value)
-- end)

-- -- Handle controller button input
-- Ext.Events.ControllerButtonInput:Subscribe(function(e)
--     -- e:PreventAction()
--     -- e:StopPropagation()
--     -- _D(e)
--     -- if e.Pressed then
--         -- print("Controller button " .. e.Button .. " pressed.")
--     -- end
-- end)

-- Common handler for configs payloads
-- REFACTOR: consolidate with InitClientMCM
local function onConfigsReceived(mods, profiles)
    if _hasReceivedConfigPayload and _hasReceivedConfigPayload == true then
        MCMDebug(1, "Received duplicate MCM config payload; skipping redundant client initialization")
        return
    end

    _hasReceivedConfigPayload = true

    MCMAPI:LoadConfigs()
    MCMClientState:LoadMods(mods)
end

-- Register generic chunked listeners once and a handler
if ChunkedNet and ChunkedNet.Client and ChunkedNet.Client.RegisterNetListeners then
    ChunkedNet.Client.RegisterNetListeners()
    -- Register handler using the channel name string (not the object) for consistency with chunk metadata
    ChunkedNet.Client.RegisterHandler("MCM_Server_Send_Configs_To_Client", function(jsonStr)
        local data = jsonStr
        if type(data) == "table" then
            onConfigsReceived(data.mods, data.profiles)
        end
    end)
end

Ext.Events.ResetCompleted:Subscribe(function()
    invalidateConfigPayloadCache()
    InitClientMCM()
end)

-- Handle direct (non-chunked) config messages
NetChannels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT:SetHandler(function(data)
    if not data or type(data) ~= "table" then
        MCMWarn(0, "Failed to parse configs payload - invalid data")
        return
    end
    onConfigsReceived(data.mods, data.profiles)
end)

NetChannels.MCM_RELAY_TO_SERVERS:SetHandler(function(data)
    if not data or not data.channel then
        MCMWarn(0, "Invalid relay data received")
        return
    end

    -- Forward to server using the appropriate NetChannel
    local targetChannel = NetChannels[data.channel]
    if targetChannel and targetChannel.SendToServer then
        targetChannel:SendToServer(data.payload)
    else
        MCMWarn(0, "Unknown channel for relay: " .. tostring(data.channel))
    end
end)

NetChannels.MCM_EMIT_ON_CLIENTS:SetHandler(function(data)
    if not data or not data.eventName then
        MCMWarn(0, "Invalid emit data received - missing eventName")
        return
    end

    local eventName = data.eventName
    local eventData = data.eventData

    MCMDebug(1, "Emitting event " .. eventName .. " on clients as well.")

    if Ext.ModEvents['BG3MCM'] and Ext.ModEvents['BG3MCM'][eventName] then
        Ext.ModEvents['BG3MCM'][eventName]:Throw(eventData)
    else
        MCMWarn(0, "Event '" .. eventName .. "' not registered")
    end
end)

NetChannels.MCM_ENSURE_MODVAR_REGISTERED:SetHandler(function(data)
    if not data or not data.varName or not data.moduleUUID then
        return
    end

    local ModVarAdapter = require("Shared/DynamicSettings/Adapters/ModVarAdapter")
    ModVarAdapter:EnsureRegistered(data.varName, data.moduleUUID, data.storageConfig, true)
end)

ModEventManager:Subscribe(EventChannels.MCM_INTERNAL_SETTING_SAVED, function(payload)
    local modUUID = payload.modUUID
    local settingId = payload.settingId
    local value = payload.value

    MCMClientState:SetClientStateValue(settingId, value, modUUID)

    IMGUIAPI:UpdateMCMWindowValues(settingId, value, modUUID)
end)

--- SECTION: Mod events
ModEventManager:Subscribe(EventChannels.MCM_SETTING_RESET, function(data)
    local modUUID = data.modUUID
    local settingId = data.settingId
    local defaultValue = data.defaultValue

    -- Update the displayed value for the setting
    IMGUIAPI:UpdateSettingUIValue(settingId, defaultValue, modUUID)
    -- MCMClientState:SetClientStateValue(settingId, defaultValue, modUUID)
end)

ModEventManager:Subscribe(EventChannels.MCM_SETTING_SAVED, function(data)
    MCMDebug(1, "Firing MCM_SETTING_SAVED on client")
    local modUUID = data.modUUID
    local settingId = data.settingId
    local value = data.value

    IMGUIAPI:UpdateSettingUIValue(settingId, value, modUUID)

    MCMClientState:SetClientStateValue(settingId, value, modUUID)

    IMGUIAPI:UpdateMCMWindowValues(settingId, value, modUUID)
end)

ModEventManager:Subscribe(EventChannels.MCM_MOD_TAB_ADDED, function(data)
    local modUUID = data.modUUID
    local tabName = data.tabName
    local tabCallback = data.tabCallback
    local skipDisclaimer = data.skipDisclaimer

    -- Update the MCMRendering to include the new tab
    IMGUIAPI:InsertModMenuTab(modUUID, tabName, tabCallback, skipDisclaimer)
end)

ModEventManager:Subscribe(EventChannels.MCM_PROFILE_ACTIVATED, function(data)
    local newSettings = data.newSettings

    for modUUID, modSettings in pairs(newSettings) do
        for settingId, settingValue in pairs(modSettings.settingsValues) do
            IMGUIAPI:UpdateSettingUIValue(settingId, settingValue, modUUID)
        end
    end
end)

MCMAPI.ConfigsLoaded:Subscribe(function(ConfigsLoaded)
    if not ConfigsLoaded then
        return
    end

    -- Use settings' values as soon as they are available, and before UI rendering
    xpcall(function()
        InitHandles:UpdateDynamicMCMWindowHandles()
    end, function(err)
        MCMError(0, "Failed to update dynamic MCM window handles: " .. tostring(err))
    end)

    xpcall(function()
        MCMPrinter:UpdateLogLevels()
    end, function(err)
        MCMError(0, "Failed to update log levels: " .. tostring(err))
    end)
end)

-- if Ext.Debug.IsDeveloperMode() then
--     InitClientMCM()
-- end
