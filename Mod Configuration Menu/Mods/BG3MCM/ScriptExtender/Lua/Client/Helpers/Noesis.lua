Noesis = {}

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
        MCMDebug(1, "MCMButton not found")
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

    local originalMessage = Ext.Loca.GetTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7")
    Ext.Loca.UpdateTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7", newMessage)
    -- Revert to original message after revertTime
    Ext.Timer.WaitFor(revertTime, function()
        Ext.Loca.UpdateTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7", originalMessage)
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
                Ext.Net.PostMessageToServer(NetChannels.MCM_CLIENT_SHOW_TROUBLESHOOTING_NOTIFICATION, Ext.Json.Stringify({}))
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

function Noesis:HandleGameMenuMCMButtonPress(button)
    handleMCMButtonPress(button, true)
end

function Noesis:HandleMainMenuMCMButtonPress(button)
    handleMCMButtonPress(button, false)
end

function Noesis:ListenToMainMenuButtonPress()
    Ext.Timer.WaitFor(4000, function()
        local MCMMainMenuButton = Noesis:FindMCMainMenuButton()
        if not MCMMainMenuButton then
            MCMDebug(1, "MCMMainMenuButton not found. Not listening for clicks on it.")
            return
        end

        self:HandleMainMenuMCMButtonPress(MCMMainMenuButton)
    end)
end
