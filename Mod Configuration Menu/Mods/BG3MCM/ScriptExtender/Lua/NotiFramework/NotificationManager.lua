---@alias NotificationLevel
---| 'info'
---| 'success'
---| 'warning'
---| 'error'

---@class NotificationOptions
---@field duration integer The duration in seconds the notification will be displayed
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
---@field private _alpha number
---@field private _timer number
---@field modUUID string
NotificationManager = _Class:Create("NotificationManager", nil, {
    IMGUIwindow = nil,
    notificationLevel = 'info',
    message = "",
    title = "Info",
    options = {
        duration = 10,
        dontShowAgainButton = true,
        dontShowAgainButtonCountdown = 5,
        showOnce = false
    },
    _alpha = 1.0,
    _timer = nil,
})

NotificationManager.NotificationStyles =
{
    error = {
        icon = "ico_exclamation_01",
        borderColor = Color.HEXToRGBA("#FF2222"),
        titleBgActive = Color.NormalizedRGBA(255, 38, 38, 1),
        titleBg = Color.NormalizedRGBA(255, 10, 10, 0.67),
    },
    warning = {
        icon = "tutorial_warning_yellow",
        borderColor = Color.HEXToRGBA("#DD9922"),
        titleBgActive = Color.NormalizedRGBA(221, 153, 34, 1),
        titleBg = Color.NormalizedRGBA(255, 140, 0, 0.67)
    },
    info = {
        icon = "talkNotice_h",
        borderColor = Color.HEXToRGBA("#22CCFF"),
        titleBgActive = Color.NormalizedRGBA(0, 100, 255, 1),
        titleBg = Color.NormalizedRGBA(0, 125, 255, 0.67),
    },
    success = {
        icon = "vendorAttitude_04",
        borderColor = Color.HEXToRGBA("#22FF22"),
        titleBgActive = Color.NormalizedRGBA(0, 155, 0, 1),
        titleBg = Color.NormalizedRGBA(30, 155, 30, 0.67),
    }
}

--- Creates a new warning IMGUIwindow
---@param id string The unique identifier for the warning IMGUIwindow
---@param level NotificationLevel The warning level
---@param title string The title of the warning IMGUIwindow
---@param message string The message to display in the IMGUIwindow
---@param options NotificationOptions The options for the warning IMGUIwindow
---@param modUUID string The UUID of the mod that owns the warning
function NotificationManager:new(id, level, title, message, options, modUUID)
    local instance = setmetatable({}, { __index = NotificationManager })
    instance.id = id
    instance.notificationLevel = level
    instance.title = title
    instance.message = message
    instance.modUUID = modUUID
    instance.options.duration = options.duration
    instance:InitializeNotificationWindow()
    return instance
end

function NotificationManager:InitializeNotificationWindow()
    self.IMGUIwindow = Ext.IMGUI.NewWindow(self.title)
    self:ConfigureWindowStyle()
    self:CreateMessageGroup()
    self:CreateDontShowAgainButton()

    -- On hover or something like that. Can't be done with current API
    -- self:ResetFadeOutTimer()

    self:StartFadeOutTimer()
end

function NotificationManager:Destroy()
    self.IMGUIwindow.Visible = false
    self.IMGUIwindow:SetCollapsed(true)
    self.IMGUIwindow:Destroy()
end

--- Resets the fade-out timer and alpha when the notification is activated
function NotificationManager:ResetFadeOutTimer()
    self.IMGUIwindow.Visible = true
    self._alpha = 1.0
    self._timer = Ext.Utils.MonotonicTime()
    self.IMGUIwindow:SetStyle("Alpha", self._alpha)

    self:StartFadeOutTimer()
end

--- Starts the fade-out effect and the auto-close of the notification window
function NotificationManager:StartFadeOutTimer()
    local notificationDuration = self.options.duration
    local fadeOutDuration = 2
    local fadeStartTime = notificationDuration - fadeOutDuration

    -- 60 FPS
    local frameInterval = 1000 / 60

    local startTime = self._timer or Ext.Utils.MonotonicTime()

    local function updateAlpha()
        self._timer = Ext.Utils.MonotonicTime()
        local timePassed = (self._timer - startTime) / 1000

        if timePassed >= fadeStartTime then
            local fadeRatio = (notificationDuration - timePassed) / fadeOutDuration
            self._alpha = fadeRatio > 0 and fadeRatio or 0
            self.IMGUIwindow:SetStyle("Alpha", self._alpha)
        end

        if timePassed >= notificationDuration then
            self:Destroy()
            self.IMGUIwindow.Visible = false
            MCMDebug(1, "Notification window closed after " .. notificationDuration .. " seconds.")
            return true
        end
        return false
    end

    VCTimer:CallWithInterval(updateAlpha, frameInterval, notificationDuration * 1000)
end

function NotificationManager:ConfigureWindowStyle()
    self.IMGUIwindow:SetStyle("Alpha", 1.0)
    self.IMGUIwindow:SetColor("WindowBg", Color.NormalizedRGBA(18, 18, 18, 1))
    self.IMGUIwindow:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    self.IMGUIwindow.AlwaysAutoResize = true
    self.IMGUIwindow.Closeable = false
    self.IMGUIwindow.Visible = true
    self.IMGUIwindow.Open = true

    self.IMGUIwindow:SetColor("TitleBg", self:GetStyleTitleBg())
    self.IMGUIwindow:SetColor("TitleBgActive", self:GetStyleTitleBgActive())
    self.IMGUIwindow:SetColor("TitleBgCollapsed", self:GetStyleTitleBg())
end

function NotificationManager:CreateMessageGroup()
    local messageGroup = self.IMGUIwindow:AddGroup("message_group")
    local iconSize = 64
    local borderColor = self:GetStyleBorderColor()
    local icon = self:GetStyleIcon()

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
function NotificationManager:GetStyleBorderColor()
    local style = self.NotificationStyles[self.notificationLevel]
    return style.borderColor
end

function NotificationManager:GetStyleIcon()
    local style = self.NotificationStyles[self.notificationLevel]
    return style.icon
end

function NotificationManager:GetStyleTitleBg()
    local style = self.NotificationStyles[self.notificationLevel]
    return style.titleBg
end

function NotificationManager:GetStyleTitleBgActive()
    local style = self.NotificationStyles[self.notificationLevel]
    return style.titleBgActive
end

function NotificationManager:CreateDontShowAgainButton(countdownTime)
    if not self.options.dontShowAgainButton then
        return
    end

    local messageGroup = self.IMGUIwindow:AddGroup("message_group")
    messageGroup:AddDummy(0, 10)

    local countdown = (countdownTime or self.options.dontShowAgainButtonCountdown) + 1
    local dontShowAgainButtonLocalizedLabel = Ext.Loca.GetTranslatedString("h8fdf52dfb8b14895a479a2bb6bd2a4af9d4f")
    local dontShowAgainButton = self.IMGUIwindow:AddButton(dontShowAgainButtonLocalizedLabel .. " (" .. countdown .. ")")

    if not dontShowAgainButton.UserData then
        dontShowAgainButton.UserData = {}
    end
    dontShowAgainButton.UserData.originalColor = dontShowAgainButton:GetColor("Button")
    -- FIXME: UserData is [] despite of this :)

    dontShowAgainButton.OnClick = function()
        -- Store the preference in JSON using NotificationPreferences
        MCMDebug(1, "Saving user preference to suppress notification: " .. self.id .. ".")
        NotificationPreferences:StoreUserDontShowPreference(self.modUUID, self.id)
        self:Destroy()
    end

    dontShowAgainButton.SameLine = false
    dontShowAgainButton.Disabled = true

    local function updateCountdownAndLabel()
        countdown = countdown - 1

        dontShowAgainButton:SetColor("Button", Color.NormalizedRGBA(50, 50, 50, 0.5))
        dontShowAgainButton.Label = dontShowAgainButtonLocalizedLabel .. " (" .. countdown .. ")"
        if countdown <= 0 then
            dontShowAgainButton.Disabled = false
            dontShowAgainButton.Label = dontShowAgainButtonLocalizedLabel
            self.IMGUIwindow.Closeable = true
            -- dontShowAgainButton:SetColor("Button", dontShowAgainButton.UserData.originalColor)
            dontShowAgainButton:SetColor("Button", UIStyle.Colors.Button)
            -- Stop the timer
            return true
        else
            -- Continue the timer
            return false
        end
    end

    -- Update the button label each second as a countdown
    VCTimer:CallWithInterval(updateCountdownAndLabel, 1000, countdown * 1000)
end

--- Displays a warning message to the user
---@param level NotificationLevel The warning level
---@param title string The title of the warning IMGUIwindow
---@param message string The message to display
---@param options NotificationOptions The options for the warning
---@param modUUID string The UUID of the mod that owns the warning
function NotificationManager:CreateIMGUINotification(id, level, title, message, options, modUUID)
    if Ext.IsClient() and NotificationPreferences:ShouldShowNotification(id, modUUID) then
        return NotificationManager:new(id, level, title, message, options, modUUID)
    end
end
