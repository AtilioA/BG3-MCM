--- SECTION: Ext events
local function handleEscapeKey()
    Ext.Timer.WaitFor(200, function()
        local MCMButton = Noesis:FindMCMGameMenuButton()
        if not MCMButton then
            MCMDebug(1, "MCMButton not found. Not listening for clicks on it.")
            return
        end
        Noesis:HandleGameMenuMCMButtonPress(MCMButton)
    end)
end

local function handleKeyInput(e)
    if e.Event == "KeyDown" and e.Repeat == false then
        KeybindingManager:HandleKeyUpInput(e)
        return
    end

    if e.Event == "KeyUp" and e.Repeat == false and e.Key == "ESCAPE" then
        handleEscapeKey()
    end
end

Ext.Events.KeyInput:Subscribe(handleKeyInput)

Ext.Events.ResetCompleted:Subscribe(function()
    MCMProxy.GameState = "Running"
    MCMAPI:LoadConfigs()
    MCMClientState:LoadMods(MCMAPI.mods)
    Ext.Net.PostMessageToServer(Channels.MCM_CLIENT_REQUEST_CONFIGS, Ext.Json.Stringify({
        message = "Client reset has completed. Requesting MCM settings from server."
    }))
    if not MCM_WINDOW then
        return
    end
    MCM_WINDOW.Visible = true
end)

--- SECTION: Net listeners
Ext.RegisterNetListener(Channels.MCM_SERVER_SEND_CONFIGS_TO_CLIENT, function(_, payload)
    local configs = Ext.Json.Parse(payload)
    local mods = configs.mods
    local profiles = configs.profiles

    MCMClientState:LoadMods(mods)
end)

Ext.RegisterNetListener(Channels.MCM_RELAY_TO_SERVERS, function(_, metapayload)
    local data = Ext.Json.Parse(metapayload)
    Ext.Net.PostMessageToServer(data.channel, Ext.Json.Stringify(data.payload))
end)

Ext.RegisterNetListener(Channels.MCM_SETTING_RESET, function(_, payload)
    local data = Ext.Json.Parse(payload)
    local modGUID = data.modGUID
    local settingId = data.settingId
    local defaultValue = data.defaultValue

    -- Update the displayed value for the setting
    IMGUIAPI:UpdateSettingUIValue(settingId, defaultValue, modGUID)
end)

local function UpdateMCMWindowValues(settingId, value, modGUID)
    if modGUID ~= ModuleUUID then
        return
    end

    if not MCM_WINDOW then
        return
    end

    if settingId == "auto_resize_window" then
        MCM_WINDOW.AlwaysAutoResize = value
    end
end

Ext.RegisterNetListener(Channels.MCM_SETTING_UPDATED, function(_, payload)
    local data = Ext.Json.Parse(payload)
    local modGUID = data.modGUID
    local settingId = data.settingId
    local value = data.value

    MCMClientState:SetClientStateValue(settingId, value, modGUID)

    UpdateMCMWindowValues(settingId, value, modGUID)
end)

Ext.RegisterNetListener(Channels.MCM_MOD_TAB_ADDED, function(_, payload)
    local data = Ext.Json.Parse(payload)
    local modGUID = data.modGUID
    local tabName = data.tabName
    local tabCallback = data.tabCallback

    -- Update the IMGUILayer to include the new tab
    IMGUIAPI:InsertModMenuTab(modGUID, tabName, tabCallback)
end)

Ext.RegisterNetListener(Channels.MCM_SERVER_SET_PROFILE, function(_, payload)
    local data = Ext.Json.Parse(payload)
    local newSettings = data.newSettings

    for modGUID, modSettings in pairs(newSettings) do
        for settingId, settingValue in pairs(modSettings.settingsValues) do
            IMGUIAPI:UpdateSettingUIValue(settingId, settingValue, modGUID)
        end
    end
end)

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
