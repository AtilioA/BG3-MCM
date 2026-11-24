Noesis = {}

MCM_BUTTON_HANDLE_ORIGINAL_CONTENT = Ext.Loca.GetTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7")

Ext.UI.RegisterType("MCMButtonDC", { CustomEvent = { Type = "Command" } })

--- Thanks Norbyte for these!
local function findNoesisElementByName(element, name)
    if not element then
        return nil
    end

    if element:GetProperty("Name") == name then
        return element
    end

    for i = 1, element.VisualChildrenCount do
        local foundElement = findNoesisElementByName(element:VisualChild(i), name)
        if foundElement then
            return foundElement
        end
    end

    return nil
end

-- TODO: move this to a separate file
local isMessageUpdated = false
local function updateButtonMessage(newMessage, revertTime)
    if isMessageUpdated then
        return
    end
    isMessageUpdated = true

    Ext.Loca.UpdateTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7", newMessage)
    -- Revert to original message after revertTime
    Ext.Timer.WaitFor(revertTime, function()
        Ext.Loca.UpdateTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7", MCM_BUTTON_HANDLE_ORIGINAL_CONTENT)
        isMessageUpdated = false
    end)
end

-- REFACTOR: remove hasServer
local function createMCMButtonPressTracker(hasServer)
    local pressCount = 0
    local pressLimit = 4
    local timeWindow = 5000
    local revertTime = 15000

    return function()
        pressCount = pressCount + 1
        if pressCount == 1 then
            Ext.Timer.WaitFor(timeWindow, function() pressCount = 0 end)
        end
        if pressCount > pressLimit then
            MCMWarn(0,
                "Trying to open MCM window. If you don't see it, please see the troubleshooting steps in the mod description.")
            updateButtonMessage(Ext.Loca.GetTranslatedString("h354808a337024c99b6149d5d1b11934bd36e"),
                revertTime)
            if hasServer then
                NetChannels.MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION:SendToServer({})
            end
        else
            MCMPrint(1,
                "Opening MCM window. If you don't see it, please see the troubleshooting steps in the mod description.")
        end
    end
end

-- MCM button per menu widget; MCM injects the buttons via its XAML overrides.
local GAME_MENU_BUTTON = { name = "MCMButton", hideSetting = "hide_game_menu_mcm_button", hasServer = true }
local MAIN_MENU_BUTTON = { name = "MCMMainMenuButton", hideSetting = "hide_main_menu_mcm_button", hasServer = false }
local MCM_BUTTONS = {
    GameMenu = GAME_MENU_BUTTON,
    GameMenu_c = GAME_MENU_BUTTON,
    MainMenu = MAIN_MENU_BUTTON,
    MainMenu_c = MAIN_MENU_BUTTON,
}
local isBindScheduled = false
local isSubscribing = false
local isListening = false

---@class NoesisChildContainer : NoesisBaseComponent
---@field ChildrenCount integer
---@field Child fun(self: NoesisChildContainer, index: integer): NoesisVisual

--- Calls fn(widgetName, button, buttonConfig) for each MCM button in the open menu widgets. Run inside Ext.UI.Defer.
local function forEachMCMButton(fn)
    local root = Ext.UI.GetRoot()
    local contentRoot = root and root:Find("ContentRoot")
    if not contentRoot then return end
    ---@cast contentRoot NoesisChildContainer
    for i = 1, contentRoot.ChildrenCount do
        local widget = contentRoot:Child(i)
        local buttonConfig = MCM_BUTTONS[widget.Name]
        local button = buttonConfig and findNoesisElementByName(widget, buttonConfig.name)
        if button then
            fn(widget.Name, button, buttonConfig)
        end
    end
end

local function setButtonHidden(button, isHidden)
    button:SetProperty("Visibility", isHidden and "Collapsed" or "Visible")
end

--- Binds each MCM button that does not have MCM's DataContext yet and syncs its visibility.
local function bindMCMButtons()
    isBindScheduled = false
    forEachMCMButton(function(widgetName, button, buttonConfig)
        setButtonHidden(button, MCM.Get(buttonConfig.hideSetting))
        if button.DataContext and button.DataContext.Type == "se::MCMButtonDC" then return end

        local ctx = Ext.UI.Instantiate("se::MCMButtonDC")
        if not ctx then return end
        local onButtonPress = createMCMButtonPressTracker(buttonConfig.hasServer)
        ctx.CustomEvent:SetHandler(function()
            onButtonPress()
            IMGUIAPI:ToggleMCMWindow(false)
        end)
        button.DataContext = ctx
        MCMDebug(1, "Bound MCM button in %s", widgetName)
    end)
end

--- Event sources have no name and expire before the next Defer, so each burst schedules one lookup pass.
local function scheduleBind()
    if isBindScheduled then return end
    isBindScheduled = true
    Ext.UI.Defer(bindMCMButtons)
end

--- Binds MCM's main menu and game menu buttons whenever their menu opens, however it was opened.
--- Noesis access outside Ext.UI.Defer can crash, hence the Defer.
--- Do not call at script load; a subscription made during LoadModule receives no LSElementAttached events.
function Noesis:ListenForMCMButtons()
    scheduleBind()
    if isSubscribing or isListening then return end
    isSubscribing = true
    local function subscribeWhenRootIsReady()
        local root = Ext.UI.GetRoot()
        if not root then
            Ext.UI.Defer(subscribeWhenRootIsReady)
            return
        end
        isSubscribing = false
        root:Subscribe("LSElementAttached", scheduleBind)
        isListening = true
        bindMCMButtons()
    end
    Ext.UI.Defer(subscribeWhenRootIsReady)
end

ModEventManager:Subscribe(EventChannels.MCM_INTERNAL_SETTING_SAVED, function(payload)
    local settingId = payload.settingId
    if payload.modUUID ~= ModuleUUID
        or (settingId ~= GAME_MENU_BUTTON.hideSetting and settingId ~= MAIN_MENU_BUTTON.hideSetting) then
        return
    end
    scheduleBind()
end)

MCMAPI.ConfigsLoaded:Subscribe(function(loaded)
    if loaded then
        scheduleBind()
    end
end)

ModEventManager:Subscribe(EventChannels.MCM_PROFILE_ACTIVATED, function()
    scheduleBind()
end)
