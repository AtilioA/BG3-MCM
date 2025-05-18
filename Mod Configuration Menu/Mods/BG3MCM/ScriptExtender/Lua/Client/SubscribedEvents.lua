local isSearchingForMCMButton = false

local function handleEscapeKey()
    if isSearchingForMCMButton then
        return
    end

    isSearchingForMCMButton = true
    VCTimer:CallWithInterval(function()
        local MCMButton = Noesis:FindMCMGameMenuButton()
        if not MCMButton then
            MCMDebug(1, "MCMButton not found. Not listening for clicks on it.")
            return nil
        end
        Noesis:HandleGameMenuMCMButtonPress(MCMButton)
        isSearchingForMCMButton = false
        return MCMButton
    end, 100, 1000)

    -- Reset the flag after the total time in case no button was found
    Ext.Timer.WaitFor(1000, function()
        isSearchingForMCMButton = false
    end)
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

--- SECTION: Ext events
Ext.Events.GameStateChanged:Subscribe(function(e)
    MCMProxy.GameState = e.ToState

    if e.ToState == Ext.Enums.ClientGameState["Menu"] then
        MCMAPI:LoadConfigs()
        MCMClientState:LoadMods(MCMAPI.mods)
        Noesis:MonitorMainMenuButtonPress()
    end
end)

Ext.Events.ResetCompleted:Subscribe(function()
    -- MCMProxy.GameState = "Running"

    -- This doesn't even work, event does not fire during the main menu :shrug:
    if MCMProxy.IsMainMenu() then
        MCMAPI:LoadConfigs()
        MCMClientState:LoadMods(MCMAPI.mods)
    else
        Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_REQUEST_CONFIGS, Ext.Json.Stringify({
            message = "Client reset has completed. Requesting MCM settings from server."
        }))
    end

    if not MCM_WINDOW then
        return
    end
    MCM_WINDOW.Visible = true
end)

Ext.Events.KeyInput:Subscribe(handleKeyInput)

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

-- TODO: add controller support
-- Ext.Events.ControllerButtonInput:Subscribe(function(e)
--     _D(e)
-- end)

--- SECTION: Net messages
Ext.RegisterNetListener(NetChannels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT, function(_, payload)
    local data = Ext.Json.Parse(payload)
    local mods = data.mods
    local profiles = data.profiles

    MCMProxy.GameState = "Running"
    MCMAPI:LoadConfigs()
    MCMClientState:LoadMods(mods)
end)

Ext.RegisterNetListener(NetChannels.MCM_RELAY_TO_SERVERS, function(_, metapayload)
    local data = Ext.Json.Parse(metapayload)
    Ext.Net.PostMessageToServer(data.channel, Ext.Json.Stringify(data.payload))
end)

Ext.RegisterNetListener(NetChannels.MCM_EMIT_ON_CLIENTS, function(_, payload)
    local data = Ext.Json.Parse(payload)
    local eventName = data.eventName
    local eventData = data.eventData

    MCMDebug(1, "Emitting event " .. eventName .. " on clients as well.")

    Ext.ModEvents['BG3MCM'][eventName]:Throw(eventData)
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

    -- Update the MCMRendering to include the new tab
    IMGUIAPI:InsertModMenuTab(modUUID, tabName, tabCallback)
end)

ModEventManager:Subscribe(EventChannels.MCM_PROFILE_ACTIVATED, function(data)
    local newSettings = data.newSettings

    for modUUID, modSettings in pairs(newSettings) do
        for settingId, settingValue in pairs(modSettings.settingsValues) do
            IMGUIAPI:UpdateSettingUIValue(settingId, settingValue, modUUID)
        end
    end
end)

-- SECTION: Noesis events
-- REFACTOR: these should be in a separate file or something
local function dynamicOpacityWrapper(func)
    return MCMUtils:ConditionalWrapper(function()
        return MCMClientState:GetClientStateValue("dynamic_opacity", ModuleUUID)
    end, func)
end

-- Thanks to Hippo0o for this idea
local function onMouseEnter()
    if not MCM_WINDOW then
        return
    end
    -- windowVisible(false)
    MCMClientState:SetActiveWindowAlpha(false)
end

local function onMouseLeave()
    if not MCM_WINDOW then
        return
    end
    -- windowVisible(true)
    MCMClientState:SetActiveWindowAlpha(true)
end
Ext.UI.GetRoot():Subscribe("MouseEnter", dynamicOpacityWrapper(onMouseEnter))
Ext.UI.GetRoot():Subscribe("MouseLeave", dynamicOpacityWrapper(onMouseLeave))
