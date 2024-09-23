-- TODO: split into separate files: NotificationManager.lua, NotificationStyles.lua, NotificationOptions.lua?

-- Indefinite duration for notifications
local DEFAULT_DURATION = nil

local DEFAULT_DONT_SHOW_AGAIN_BUTTON_COUNTDOWN = 5
local FADE_OUT_DURATION = 2
-- 60 FPS
local FRAME_INTERVAL = 1000 / 60
local ICON_SIZE = 64

---@alias NotificationLevel
---| 'info'
---| 'success'
---| 'warning'
---| 'error'

---@class NotificationOptions
---@field duration integer|nil? The duration in seconds the notification will be displayed
---@field dontShowAgainButton boolean? If true, a 'Don't show again' button will be displayed
---@field dontShowAgainButtonCountdownInSec integer? The countdown time in seconds for the 'Don't show again' button
---@field showOnce boolean? If true, the notification will only be shown once

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
        duration = DEFAULT_DURATION,
        dontShowAgainButton = true,
        dontShowAgainButtonCountdownInSec = DEFAULT_DONT_SHOW_AGAIN_BUTTON_COUNTDOWN,
        showOnce = false
    },
    _alpha = 1.0,
    _timer = nil,
})

---@class NotificationStyle
---@field icon string The icon name to display in the notification
---@field borderColor table<number> The RGBA color of the border
---@field titleBgActive table<number> The RGBA color of the active title background
---@field titleBg table<number> The RGBA color of the title background
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
        icon = "ico_classRes_luck",
        borderColor = Color.HEXToRGBA("#22FF22"),
        titleBgActive = Color.NormalizedRGBA(0, 155, 0, 1),
        titleBg = Color.NormalizedRGBA(30, 155, 30, 0.67),
    }
}

--- Preprocesses options to ensure they are valid and consistent
--- e.g.: duration should be at least the same as the countdown, showOnce should not be enabled if the button is enabled
---@param options NotificationOptions The options to preprocess
---@return NotificationOptions The processed options
local function preprocessOptions(options)
    if options.duration then
        options.duration = math.max(options.duration, options.dontShowAgainButtonCountdownInSec)
    end

    options.showOnce = options.showOnce and not options.dontShowAgainButton
    return options
end

--- Creates a new warning IMGUIwindow
---@param id string The unique identifier for the warning IMGUIwindow
---@param level NotificationLevel The warning level
---@param title string The title of the warning IMGUIwindow
---@param message string The message to display in the IMGUIwindow
---@param options NotificationOptions The options for the warning IMGUIwindow
---@param modUUID string The UUID of the mod that owns the warning
---@return NotificationManager
function NotificationManager:new(id, level, title, message, options, modUUID)
    -- Preprocess options for validity
    options = preprocessOptions(options)
    local instance = _MetaClass.New(NotificationManager, {
        id = id,
        notificationLevel = level,
        title = title,
        message = message,
        modUUID = modUUID,
        options = {
            duration = options.duration,
            dontShowAgainButton = options.dontShowAgainButton,
            dontShowAgainButtonCountdownInSec = options.dontShowAgainButtonCountdownInSec,
            showOnce = options.showOnce
        }
    })
    instance:InitializeNotificationWindow()
    return instance
end

--- Initializes the notification window and sets up its components
---@return nil
function NotificationManager:InitializeNotificationWindow()
    self.IMGUIwindow = Ext.IMGUI.NewWindow(self.title)
    self:ConfigureWindowStyle()
    self:CreateMessageGroup()
    self:CreateDontShowAgainButton()

    -- Also missing from the SE IMGUI API
    -- self.IMGUIwindow:OnClose(function()
    --     -- or HandleShowOnce?
    --     self:Destroy()
    -- end)

    -- On hover or something like that. Can't be done with current API
    -- self:ResetFadeOutTimer()

    self:StartFadeOutTimer()
end

--- Cleans up and destroys the IMGUIwindow, also handling the show once parameter
---@return nil
function NotificationManager:Destroy()
    self.IMGUIwindow.Visible = false
    self.IMGUIwindow:SetCollapsed(true)
    self.IMGUIwindow:Destroy()

    self:HandleShowOnce()
end

--- Stores the user preference to not show the notification again, if the option is enabled
---@return nil
function NotificationManager:HandleShowOnce()
    if self.options.showOnce == true then
        NotificationPreferences:StoreUserDontShowPreference(self.modUUID, self.id)
    end
end

--- Resets the fade-out timer and alpha when the notification is activated (unused)
---@return nil
function NotificationManager:ResetFadeOutTimer()
    self.IMGUIwindow.Visible = true
    self._alpha = 1.0
    self._timer = Ext.Utils.MonotonicTime()
    self.IMGUIwindow:SetStyle("Alpha", self._alpha)

    self:StartFadeOutTimer()
end

--- Starts the fade-out effect and the auto-close of the notification window
---@return nil
function NotificationManager:StartFadeOutTimer()
    if not self.options or not self.options.duration then return end
    local notificationDuration = self.options.duration
    local fadeStartTime = notificationDuration - FADE_OUT_DURATION

    local startTime = self._timer or Ext.Utils.MonotonicTime()

    local function updateAlpha()
        -- TODO: update title with remaining duration?
        self._timer = Ext.Utils.MonotonicTime()
        local timePassed = (self._timer - startTime) / 1000

        if timePassed >= fadeStartTime then
            local fadeRatio = (notificationDuration - timePassed) / FADE_OUT_DURATION
            self._alpha = fadeRatio > 0 and fadeRatio or 0
            if self.IMGUIwindow then
                self.IMGUIwindow:SetStyle("Alpha", self._alpha)
            end
        end

        if timePassed >= notificationDuration then
            self:Destroy()
            MCMDebug(1, "Notification window closed after " .. notificationDuration .. " seconds.")
            return true
        end
        return false
    end

    VCTimer:CallWithInterval(updateAlpha, FRAME_INTERVAL, notificationDuration * 1000)
end

--- Configures the style of the notification window
---@return nil
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

--- Creates a message group within the notification window
---@return nil
function NotificationManager:CreateMessageGroup()
    local messageGroup = self.IMGUIwindow:AddGroup("message_group")
    local borderColor = self:GetStyleBorderColor()
    local icon = self:GetStyleIcon()

    local itemIcon = messageGroup:AddImage(icon, { ICON_SIZE, ICON_SIZE })
    if itemIcon then
        itemIcon.SameLine = true
        itemIcon.Border = borderColor
        itemIcon.IDContext = "WarningIcon"
    end

    local messageText = messageGroup:AddText(self.message)
    messageText:SetColor("Text", borderColor)
    messageText.SameLine = true
end

--- Gets the border color style for the notification level
---@return table<number>
function NotificationManager:GetStyleBorderColor()
    local style = self.NotificationStyles[self.notificationLevel]
    return style.borderColor
end

--- Gets the icon style for the notification level
---@return string
function NotificationManager:GetStyleIcon()
    local style = self.NotificationStyles[self.notificationLevel]
    return style.icon
end

--- Gets the title background style for the notification level
---@return table<number>
function NotificationManager:GetStyleTitleBg()
    local style = self.NotificationStyles[self.notificationLevel]
    return style.titleBg
end

--- Gets the active title background style for the notification level
---@return table<number>
function NotificationManager:GetStyleTitleBgActive()
    local style = self.NotificationStyles[self.notificationLevel]
    return style.titleBgActive
end

--- Creates a "Don't show again" button in the notification window
---@param countdownTimeInSec number? Optional countdown time for the button
---@return nil
function NotificationManager:CreateDontShowAgainButton(countdownTimeInSec)
    if not self.options.dontShowAgainButton then
        return
    end

    self.IMGUIwindow:AddDummy(0, 10)

    local countdown = (countdownTimeInSec or self.options.dontShowAgainButtonCountdownInSec) + 1
    local dontShowAgainButtonLocalizedLabel = Ext.Loca.GetTranslatedString("h8fdf52dfb8b14895a479a2bb6bd2a4af9d4f")
    local dontShowAgainButton = self:CreateIMGUIDontShowAgainButton(countdown, dontShowAgainButtonLocalizedLabel)

    self:SetupDontShowAgainButtonOnClick(dontShowAgainButton)
    self:StartButtonCountdown(dontShowAgainButton, countdown)
end

--- Creates a button for the notification
---@param countdown number The countdown time for the button
---@param label string The label for the button
---@return ExtuiButton button The created button
function NotificationManager:CreateIMGUIDontShowAgainButton(countdown, label)
    local buttonLabel = label
    if countdown then
        buttonLabel = buttonLabel .. " (" .. countdown .. ")"
    end

    local button = self.IMGUIwindow:AddButton(buttonLabel)
    button.UserData = button.UserData or {}
    button.UserData.originalColor = button:GetColor("Button")
    button.SameLine = false
    button.Disabled = true
    return button
end

--- Sets up the "Don't show again" button's click behavior
---@param button ExtuiButton The button to set up
---@return nil
function NotificationManager:SetupDontShowAgainButtonOnClick(button)
    button.OnClick = function()
        MCMDebug(1, "Saving user preference to suppress notification: " .. self.id .. ".")
        NotificationPreferences:StoreUserDontShowPreference(self.modUUID, self.id)
        self:Destroy()
    end
end

--- Starts the countdown for the button and updates its label
---@param button ExtuiButton The button to start the countdown on
---@param countdown number|nil The initial countdown time
---@return nil
function NotificationManager:StartButtonCountdown(button, countdown)
    if not countdown then
        return
    end
    local dontShowAgainButtonLocalizedLabel = Ext.Loca.GetTranslatedString("h8fdf52dfb8b14895a479a2bb6bd2a4af9d4f")

    local function updateCountdownAndLabel()
        countdown = countdown - 1
        button:SetColor("Button", Color.NormalizedRGBA(50, 50, 50, 0.5))
        button.Label = dontShowAgainButtonLocalizedLabel .. " (" .. countdown .. ")"

        if countdown <= 0 then
            button.Disabled = false
            button.Label = button.Label:match("^(.*) %(%d+%)")
            self.IMGUIwindow.Closeable = true
            button:SetColor("Button", UIStyle.Colors.Button)
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
