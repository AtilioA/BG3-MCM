---@alias NotificationLevel
---| 'info'
---| 'success'
---| 'warning'
---| 'error'

---@class NotificationOptions
---@field dontShowAgainButton boolean If true, a 'Don't show again' button will be displayed
---@field dontShowAgainButtonCountdown integer The countdown time in seconds for the 'Don't show again' button
---@field showOnce boolean (UNIMPLEMENTED) If true, the notification will only be shown once

---@class NotificationManager
---@field IMGUIwindow ExtuiWindow
---@field id string
---@field notificationLevel NotificationLevel
---@field message string
---@field title string
---@field options NotificationOptions
NotificationManager = _Class:Create("NotificationManager", nil, {
    IMGUIwindow = nil,
    notificationLevel = 'info',
    message = "",
    title = "Info",
    options = {
        dontShowAgainButton = true,
        dontShowAgainButtonCountdown = 5,
        showOnce = false
    }
})

--- Creates a new warning IMGUIwindow
---@param id string The unique identifier for the warning IMGUIwindow
---@param level NotificationLevel The warning level
---@param title string The title of the warning IMGUIwindow
---@param message string The message to display in the IMGUIwindow
function NotificationManager:new(id, level, title, message)
    local instance = setmetatable({}, { __index = NotificationManager })
    instance.id = id
    instance.notificationLevel = level
    instance.message = message
    instance.title = title
    instance:InitializeNotificationWindow()
    return instance
end

function NotificationManager:InitializeNotificationWindow()
    self.IMGUIwindow = Ext.IMGUI.NewWindow(self.title)
    self:ConfigureWindowStyle()
    self:CreateMessageGroup()
    self:CreateDontShowButton()
end

function NotificationManager:ConfigureWindowStyle()
    self.IMGUIwindow:SetStyle("Alpha", 1.0)
    self.IMGUIwindow:SetColor("TitleBgActive", Color.NormalizedRGBA(255, 10, 10, 1))
    self.IMGUIwindow:SetColor("TitleBg", Color.NormalizedRGBA(255, 38, 38, 0.78))
    self.IMGUIwindow:SetColor("WindowBg", Color.NormalizedRGBA(18, 18, 18, 1))
    self.IMGUIwindow:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    self.IMGUIwindow.AlwaysAutoResize = true
    self.IMGUIwindow.Closeable = false
    self.IMGUIwindow.Visible = true
    self.IMGUIwindow.Open = true
end

function NotificationManager:CreateMessageGroup()
    local messageGroup = self.IMGUIwindow:AddGroup("message_group")
    local iconSize = 64
    local borderColor, icon = self:GetIconAndBorderColor()

    local itemIcon = messageGroup:AddImage(icon, { iconSize, iconSize })
    if itemIcon then
        itemIcon.SameLine = true
        itemIcon.Border = borderColor
        itemIcon.IDContext = "WarningIcon"
    end

    local messageText = messageGroup:AddText(self.message)
    messageText:SetColor("Text", borderColor)
    messageText.SameLine = true
end

-- TODO: get proper icons for each level
function NotificationManager:GetIconAndBorderColor()
    local borderColor = Color.HEXToRGBA("#FF2222")
    local icon = "talkNotice_h"

    if self.notificationLevel == 'warning' then
        icon = "ico_exclamation_01"
    elseif self.notificationLevel == 'error' then
        borderColor = Color.HEXToRGBA("#FF9922")
        icon = "tutorial_warning_yellow"
    elseif self.notificationLevel == 'info' then
        icon = "talkNotice_h"
        borderColor = Color.HEXToRGBA("#22CCFF")
    elseif self.notificationLevel == 'success' then
        icon = "vendorAttitude_04"
        borderColor = Color.HEXToRGBA("#22FF22")
    end
    return borderColor, icon
end

function NotificationManager:CreateDontShowButton(countdownTime)
    if not self.options.dontShowAgainButton then
        return
    end

    local messageGroup = self.IMGUIwindow:AddGroup("message_group")
    messageGroup:AddDummy(0, 10)
    local countdown = countdownTime or self.options.dontShowAgainButtonCountdown
    local dontShowButton = self.IMGUIwindow:AddButton("Don't show this again (" .. countdown .. ")")
    dontShowButton.OnClick = function()
        -- Store the preference in JSON using NotificationPreferences
        MCMDebug(1, "Saving user preference to suppress notification: " .. self.id .. ".")
        NotificationPreferences:StoreUserDontShowPreference(self.id)
        self.IMGUIwindow.Visible = false
        self.IMGUIwindow:SetCollapsed(true)
        self.IMGUIwindow:Destroy()
    end
    dontShowButton.SameLine = false
    dontShowButton.Disabled = true

    local function updateCountdownAndLabel()
        countdown = countdown - 1
        dontShowButton.Label = "Don't show this again (" .. countdown .. ")"
        if countdown <= 0 then
            dontShowButton.Disabled = false
            dontShowButton.Label = "Don't show this again"
            self.IMGUIwindow.Closeable = true
            -- Stop the timer
            return false
        end
        -- Continue the timer
        return true
    end

    -- Update the button label each second as a countdown
    VCTimer:CallWithInterval(updateCountdownAndLabel, 1000, countdownTime * 1000)
end

--- Displays a warning message to the user
---@param level NotificationLevel The warning level
---@param title string The title of the warning IMGUIwindow
---@param message string The message to display
function NotificationManager:CreateIMGUINotification(id, level, title, message)
    if Ext.IsClient() and NotificationPreferences:ShouldShowNotification(id) then
        return NotificationManager:new(id, level, title, message)
    end
end
