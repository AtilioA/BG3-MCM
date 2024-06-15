--- SECTION: Ext events

-- TODO: move this to a separate file
local function updateButtonMessage(newMessage, revertTime, isMessageUpdated)
    if isMessageUpdated then
        return
    end
    isMessageUpdated = true

    local originalMessage = Ext.Loca.GetTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7")
    Ext.Loca.UpdateTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7", newMessage)
    -- Revert to original message after revertTime
    Ext.Timer.WaitFor(revertTime, function()
        Ext.Loca.UpdateTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7", originalMessage)
        isMessageUpdated = false
    end)
end

local function handleButtonPress(button)
    local pressCount = 0
    local pressLimit = 4
    local timeWindow = 4000
    local revertTime = 15000
    local isMessageUpdated = false

    button:Subscribe("PreviewMouseDown", function(a, b)
        pressCount = pressCount + 1
        if pressCount > pressLimit then
            MCMWarn(0,
                "Trying to open MCM window. If you don't see it, please see the troubleshooting steps in the mod description.")
            Ext.Net.PostMessageToServer(Channels.MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION, Ext.Json.Stringify({}))
            updateButtonMessage("No MCM window? See troubleshooting steps in the mod page.", originalMessage,
                revertTime, isMessageUpdated)
        else
            Ext.Timer.WaitFor(timeWindow, function()
                pressCount = 0
            end)
        end
        MCMPrint(1,
            "Opening MCM window. If you don't see it, please see the troubleshooting steps in the mod description.")
        MCMClientState:ToggleMCMWindow()
    end)
end

local function handleEscapeKey()
    local MCMButton = Noesis:FindMCMGameMenuButton()
    if not MCMButton then
        return
    end
    handleButtonPress(MCMButton)
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

local function UpdateMCMValues(settingId, value, modGUID)
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

    UpdateMCMValues(settingId, value, modGUID)
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
