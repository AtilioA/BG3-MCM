Noesis = {}

MCM_BUTTON_HANDLE_ORIGINAL_CONTENT = Ext.Loca.GetTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7")

local isSearchingForMCMButton = false

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

function Noesis:FindWidgetChild(widgetName, name)
    local root = Ext.UI.GetRoot():Find("ContentRoot")
    if not root then
        MCMError(0, "ContentRoot not found")
        return nil
    end

    local ok, result = xpcall(function()
        for i = 1, root.ChildrenCount do
            local widget = root:Child(i)
            if widget.Name == widgetName then
                return findNoesisElementByName(widget, name)
            end
        end
        return nil
    end, function(err)
        MCMError(0, "Error finding widget: " .. tostring(err))
        return nil
    end)

    if ok then
        return result
    else
        return nil
    end
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
        MCMDebug(3, target.Type .. " (" .. (target:GetProperty("Name") or "") .. ")")
        return target
    else
        -- MCMDebug(1, "MCMButton not found")
    end
end

function Noesis:FindMCMGameMenuButton_c()
    local target = Noesis:FindWidgetChild("GameMenu_c", "MCMButton")
    if target then
        MCMDebug(3, target.Type .. " (" .. (target:GetProperty("Name") or "") .. ")")
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
        MCMDebug(1, target.Type .. " (" .. (target:GetProperty("Name") or "") .. ")")
        return target
    else
        MCMDebug(1, "MCMMainMenuButton not found")
    end
end

function Noesis:FindMCMMainMenuButton_c()
    local target = Noesis:FindWidgetChild("MainMenu_c", "MCMMainMenuButton")
    if target then
        MCMDebug(1, target.Type .. " (" .. (target:GetProperty("Name") or "") .. ")")
        return target
    else
        MCMDebug(1, "MCMMainMenuButton not found")
    end
end

-- TODO: move this to a separate file
local function updateButtonMessage(newMessage, revertTime, isMessageUpdated)
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
    local isMessageUpdated = false

    local function onPointerDown(a, b)
        pressCount = pressCount + 1
        if pressCount > pressLimit then
            MCMWarn(0,
                "Trying to open MCM window. If you don't see it, please see the troubleshooting steps in the mod description.")
            updateButtonMessage(Ext.Loca.GetTranslatedString("h354808a337024c99b6149d5d1b11934bd36e"),
                revertTime, isMessageUpdated)
            if hasServer then
                Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION,
                    Ext.Json.Stringify({}))
            end
        else
            Ext.Timer.WaitFor(timeWindow, function()
                pressCount = 0
            end)
            MCMPrint(1,
                "Opening MCM window. If you don't see it, please see the troubleshooting steps in the mod description.")
        end
        -- IMGUIAPI:ToggleMCMWindow(false)
    end

    -- Unsubscribes automatically after the lifetime expires
    button:Subscribe("MouseLeftButtonDown", onPointerDown)
end

function Noesis:HandleGameMenuMCMButtonPress(button)
    handleMCMButtonPress(button, true)
end

function Noesis:HandleMainMenuMCMButtonPress(button)
    handleMCMButtonPress(button, false)
end

--- Handles search of MCM button on game menu.
--- @param isController boolean - Whether to search for the button on controller UI or not
function Noesis:MonitorMCMGameMenuButtonPress(isController)
    if isSearchingForMCMButton then
        return
    end

    isSearchingForMCMButton = true
    VCTimer:CallWithInterval(function()
        local MCMButton = nil
        MCMButton = Noesis:FindMCMGameMenuButton(isController)
        if not MCMButton then
            MCMDebug(1, "MCMButton not found. Not listening for clicks on it.")
            return nil
        end
        isSearchingForMCMButton = false
        -- if hasRegisteredGameMenuHandler then
        --     MCMWarn(0, "GameMenuMCMButtonDC already registered. Skipping registration.")
        --     return true
        -- end

        Ext.UI.RegisterType("GameMenuMCMButtonDC", {
            CustomEvent = { Type = "Command" },
        })
        local ctx = Ext.UI.Instantiate("se::GameMenuMCMButtonDC")
        ctx.CustomEvent:SetHandler(function()
            IMGUIAPI:ToggleMCMWindow(false)
        end)
        MCMButton.DataContext = ctx

        -- Kept for troubleshooting purposes (shows warning)
        Noesis:HandleGameMenuMCMButtonPress(MCMButton)

        return MCMButton
    end, 100, 1000)

    -- Reset the flag after the total time in case no button was found
    Ext.Timer.WaitFor(1000, function()
        isSearchingForMCMButton = false
    end)
end

function Noesis:MonitorMainMenuButtonPress()
    VCTimer:ExecuteWithIntervalUntilCondition(function()
        local isController = Gamepad.IsHostUsingGamepad()

        local mainMenuButton = Noesis:FindMCMMainMenuButton(isController)
        if not mainMenuButton then
            MCMDebug(1, "Main menu button not found. Unable to monitor clicks.")
            return false
        end

        Ext.UI.RegisterType("MainMenuMCMButtonDC", {
            CustomEvent = { Type = "Command" }
        })

        local ctx = Ext.UI.Instantiate("se::MainMenuMCMButtonDC")
        ctx.CustomEvent:SetHandler(function()
            IMGUIAPI:ToggleMCMWindow(false)
        end)
        mainMenuButton.DataContext = ctx

        self:HandleMainMenuMCMButtonPress(mainMenuButton)

        return mainMenuButton ~= nil
    end, 2000, function() return not MCMProxy:IsMainMenu() end)
end
