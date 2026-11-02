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
local function handleMCMButtonPress(button, hasServer)
    local pressCount = 0
    local pressLimit = 4
    local timeWindow = 5000
    local revertTime = 15000

    local function onPointerDown()
        Ext.OnNextTick(function()
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
            -- IMGUIAPI:ToggleMCMWindow(false)
        end)
    end

    -- Unsubscribes automatically after the lifetime expires
    button:Subscribe("PreviewMouseLeftButtonDown", onPointerDown)
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
local isListening = false

--- Calls fn(widgetName, button, buttonConfig) for each MCM button in the open menu widgets. Run inside Ext.UI.Defer.
local function forEachMCMButton(fn)
    local contentRoot = Ext.UI.GetRoot():Find("ContentRoot")
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

--- Binds each MCM button that does not have MCM's DataContext yet.
local function bindMCMButtons()
    isBindScheduled = false
    forEachMCMButton(function(widgetName, button, buttonConfig)
        if button.DataContext.Type == "se::MCMButtonDC" then return end

        setButtonHidden(button, MCM.Get(buttonConfig.hideSetting))
        local ctx = Ext.UI.Instantiate("se::MCMButtonDC")
        ctx.CustomEvent:SetHandler(function() IMGUIAPI:ToggleMCMWindow(false) end)
        button.DataContext = ctx
        -- Kept for troubleshooting purposes (shows warning)
        handleMCMButtonPress(button, buttonConfig.hasServer)
        MCMDebug(1, "Bound MCM button in %s", widgetName)
    end)
end

--- Event sources have no name and expire before the next Defer, so each burst schedules one lookup pass.
local function onElementAttached()
    if isBindScheduled then return end
    isBindScheduled = true
    Ext.UI.Defer(bindMCMButtons)
end

--- Binds MCM's main menu and game menu buttons whenever their menu opens, however it was opened.
--- Noesis access outside Ext.UI.Defer can crash, hence the Defer.
function Noesis:ListenForMCMButtons()
    if isListening then return end
    isListening = true
    Ext.UI.Defer(function()
        Ext.UI.GetRoot():Subscribe("LSElementAttached", onElementAttached)
        -- Menus attached before the subscription raise no event
        bindMCMButtons()
    end)
end

ModEventManager:Subscribe(EventChannels.MCM_INTERNAL_SETTING_SAVED, function(payload)
    local settingId = payload.settingId
    if payload.modUUID ~= ModuleUUID
        or (settingId ~= GAME_MENU_BUTTON.hideSetting and settingId ~= MAIN_MENU_BUTTON.hideSetting) then
        return
    end
    Ext.UI.Defer(function()
        forEachMCMButton(function(_, button, buttonConfig)
            if buttonConfig.hideSetting == settingId then setButtonHidden(button, payload.value) end
        end)
    end)
end)
