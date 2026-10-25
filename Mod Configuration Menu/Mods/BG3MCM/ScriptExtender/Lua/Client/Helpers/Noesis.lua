Noesis = {}

MCM_BUTTON_HANDLE_ORIGINAL_CONTENT = Ext.Loca.GetTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7")

Ext.UI.RegisterType("GameMenuMCMButtonDC", { CustomEvent = { Type = "Command" } })
Ext.UI.RegisterType("MainMenuMCMButtonDC", { CustomEvent = { Type = "Command" } })

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

--- Consume the returned object in the same Ext.UI.Defer callback.
function Noesis:FindWidgetChild(widgetName, name)
    local uiRoot = Ext.UI.GetRoot()
    if not uiRoot then
        return nil
    end

    local root = uiRoot:Find("ContentRoot")
    if not root then
        MCMError(0, "ContentRoot not found")
        return nil
    end

    for i = 1, root.ChildrenCount do
        local widget = root:Child(i)
        if widget.Name == widgetName then
            return findNoesisElementByName(widget, name)
        end
    end
    return nil
end

function Noesis:FindMCMGameMenuButton(isController)
    if isController then
        return Noesis:FindMCMGameMenuButton_c()
    else
        return Noesis:FindMCMGameMenuButton_k()
    end
end

function Noesis:FindMCMGameMenuButton_k()
    local target = Noesis:FindWidgetChild("GameMenu", "MCMButton")
    if target then
        MCMDebug(3, "%s (%s)", target.Type, target:GetProperty("Name") or "")
        return target
    else
        -- MCMDebug(1, "MCMButton not found")
    end
end

function Noesis:FindMCMGameMenuButton_c()
    local target = Noesis:FindWidgetChild("GameMenu_c", "MCMButton")
    if target then
        MCMDebug(3, "%s (%s)", target.Type, target:GetProperty("Name") or "")
        return target
    else
        -- MCMDebug(1, "MCMButton not found")
    end
end

function Noesis:FindMCMMainMenuButton(isController)
    if isController then
        return Noesis:FindMCMMainMenuButton_c()
    else
        return Noesis:FindMCMMainMenuButton_k()
    end
end

function Noesis:FindMCMMainMenuButton_k()
    local target = Noesis:FindWidgetChild("MainMenu", "MCMMainMenuButton")
    if target then
        MCMDebug(1, "%s (%s)", target.Type, target:GetProperty("Name") or "")
        return target
    else
        MCMDebug(1, "MCMMainMenuButton not found")
    end
end

function Noesis:FindMCMMainMenuButton_c()
    local target = Noesis:FindWidgetChild("MainMenu_c", "MCMMainMenuButton")
    if target then
        MCMDebug(1, "%s (%s)", target.Type, target:GetProperty("Name") or "")
        return target
    else
        MCMDebug(1, "MCMMainMenuButton not found")
    end
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

function Noesis:HandleGameMenuMCMButtonPress(button)
    handleMCMButtonPress(button, true)
end

function Noesis:HandleMainMenuMCMButtonPress(button)
    handleMCMButtonPress(button, false)
end

--- Binds the MCM button of each game menu widget that appears during a short search window.
--- The game creates a new widget on each open, so a search started by a closing ESC must not stop at the old widget.
--- @param isController boolean - Whether to search for the button on controller UI or not
function Noesis:MonitorMCMGameMenuButtonPress(isController)
    VCTimer:CallWithInterval(function()
        Ext.UI.Defer(function()
            local button = Noesis:FindMCMGameMenuButton(isController)
            if not button then
                MCMDebug(1, "MCMButton not found. Not listening for clicks on it.")
                return
            end
            local dataContext = button.DataContext
            if dataContext and dataContext.Type == "se::GameMenuMCMButtonDC" then
                return
            end
            local ctx = Ext.UI.Instantiate("se::GameMenuMCMButtonDC")
            ctx.CustomEvent:SetHandler(function() IMGUIAPI:ToggleMCMWindow(false) end)
            button.DataContext = ctx
            -- Kept for troubleshooting purposes (shows warning)
            Noesis:HandleGameMenuMCMButtonPress(button)
        end)
    end, 100, 1000)
end

function Noesis:MonitorMainMenuButtonPress()
    local bound = false
    local pending = false
    VCTimer:ExecuteWithIntervalUntilCondition(function()
        if bound then return true end
        if pending then return false end
        local isController = Gamepad.IsHostUsingGamepad()
        local hideButton = MCM.Get("hide_main_menu_mcm_button")
        pending = true
        Ext.UI.Defer(function()
            pending = false
            local mainMenuButton = Noesis:FindMCMMainMenuButton(isController)
            if not mainMenuButton then
                MCMDebug(1, "Main menu button not found. Unable to monitor clicks.")
                return
            end
            if hideButton then
                mainMenuButton:SetProperty("Visibility", "Collapsed")
            end

            local ctx = Ext.UI.Instantiate("se::MainMenuMCMButtonDC")
            ctx.CustomEvent:SetHandler(function()
                IMGUIAPI:ToggleMCMWindow(false)
            end)
            mainMenuButton.DataContext = ctx

            self:HandleMainMenuMCMButtonPress(mainMenuButton)

            bound = true
        end)
        return false
    end, 2000, function() return not MCMProxy:IsMainMenu() end)
end
