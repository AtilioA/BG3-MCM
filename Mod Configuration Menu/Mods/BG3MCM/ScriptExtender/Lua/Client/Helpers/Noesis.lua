Noesis = {}

MCM_BUTTON_HANDLE_ORIGINAL_CONTENT = Ext.Loca.GetTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7")

--- Thanks Norbyte for this!
function Noesis:findNoesisElementByName(element, name)
    if not element then
        return nil
    end

    if element:GetProperty("Name") == name then
        return element
    end

    for i = 1, element.VisualChildrenCount do
        local foundElement = self:findNoesisElementByName(element:VisualChild(i), name)
        if foundElement then
            return foundElement
        end
    end

    return nil
end

function Noesis:FindMCMGameMenuButton()
    local target = self:findNoesisElementByName(Ext.UI.GetRoot(), "MCMButton")
    if target then
        MCMDebug(3, target.Type .. " (" .. (target:GetProperty("Name") or "") .. ")")
        return target
    else
        -- MCMDebug(1, "MCMButton not found")
    end
end

function Noesis:FindMCMainMenuButton()
    local target = self:findNoesisElementByName(Ext.UI.GetRoot(), "MCMMainMenuButton")
    if target then
        MCMDebug(0, target.Type .. " (" .. (target:GetProperty("Name") or "") .. ")")
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

    button:Subscribe("PreviewMouseDown", function(a, b)
        pressCount = pressCount + 1
        if pressCount > pressLimit then
            MCMWarn(0,
                "Trying to open MCM window. If you don't see it, please see the troubleshooting steps in the mod description.")
            updateButtonMessage("No MCM window? See troubleshooting steps in the mod page.",
                revertTime, isMessageUpdated)
            if hasServer then
                Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION,
                    Ext.Json.Stringify({}))
            end
        else
            Ext.Timer.WaitFor(timeWindow, function()
                pressCount = 0
            end)
        end
        MCMPrint(1,
            "Opening MCM window. If you don't see it, please see the troubleshooting steps in the mod description.")
        MCMClientState:ToggleMCMWindow(false)
    end)
end

local function getOriginalFontSize(mainMenuButton)
    local optionsButton = Noesis:findNoesisElementByName(mainMenuButton, "OptionsButton")
    if optionsButton then
        return optionsButton:GetProperty("FontSize")
    end
    return 32
end

function Noesis:HandleGameMenuMCMButtonPress(button)
    handleMCMButtonPress(button, true)
end

function Noesis:HandleMainMenuMCMButtonPress(button)
    handleMCMButtonPress(button, false)
end

function Noesis:MonitorMainMenuButtonPress()
    VCTimer:ExecuteWithIntervalUntilCondition(function()
        local mainMenuButton = Noesis:FindMCMainMenuButton()
        if not mainMenuButton then
            MCMDebug(1, "Main menu button not found. Unable to monitor clicks.")
            return false
        end

        mainMenuButton:SetProperty("FontSize", getOriginalFontSize(mainMenuButton))

        self:HandleMainMenuMCMButtonPress(mainMenuButton)
        return mainMenuButton ~= nil
    end, 2000, function() return not MCMProxy:IsMainMenu() end)
end
