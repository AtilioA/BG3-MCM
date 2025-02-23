-- Indefinite duration for notifications
local DEFAULT_DURATION = nil

local DEFAULT_DONT_SHOW_AGAIN_BUTTON = true
local DEFAULT_DONT_SHOW_AGAIN_BUTTON_COUNTDOWN = 5

local FADE_OUT_DURATION = 2
-- 60 FPS
local FRAME_INTERVAL = 1000 / 60
local ICON_SIZE = 64

---@class NotificationManager
---@field IMGUIwindow ExtuiWindow
---@field id string
---@field notificationSeverity NotificationSeverity
---@field message string
---@field title string
---@field options NotificationOptions
---@field private _alpha number
---@field private _timer number
---@field modUUID string
NotificationManager = _Class:Create("NotificationManager", nil, {
    IMGUIwindow = nil,
    notificationSeverity = 'info',
    message = "",
    title = "Info",
    options = {
        duration = DEFAULT_DURATION,
        dontShowAgainButton = DEFAULT_DONT_SHOW_AGAIN_BUTTON,
        dontShowAgainButtonCountdownInSec = DEFAULT_DONT_SHOW_AGAIN_BUTTON_COUNTDOWN,
        displayOnceOnly = false,
    },
    _alpha = 1.0,
    _timer = nil,
})

--- Returns a table of all possible NotificationOptions fields
--- The keys will be the possible fields from NotificationOptions
---@return table<string, string>
function NotificationManager:GetAvailableNotificationOptions()
    return {
        duration = "integer|nil",
        dontShowAgainButton = "boolean|nil",
        dontShowAgainButtonCountdownInSec = "integer|nil",
        displayOnceOnly = "boolean|nil",
    }
end

--- Creates a new warning IMGUIwindow
---@param id string The unique identifier for the warning IMGUIwindow
---@param severity NotificationSeverity The warning severity
---@param title string The title of the warning IMGUIwindow
---@param message string The message to display in the IMGUIwindow
---@param options NotificationOptions The options for the warning IMGUIwindow
---@param modUUID string The UUID of the mod that owns the warning
---@return NotificationManager
function NotificationManager:new(id, severity, title, message, options, modUUID)
    -- Preprocess options for validity
    options = NotificationOptions:PreprocessOptions(options)
    local dontShowAgainButton = options.dontShowAgainButton
    if dontShowAgainButton == nil then
        dontShowAgainButton = DEFAULT_DONT_SHOW_AGAIN_BUTTON
    end

    local instance = _MetaClass.New(NotificationManager, {
        id = id,
        notificationSeverity = severity,
        title = title,
        message = message,
        modUUID = modUUID,
        options = {
            duration = options.duration,
            -- This shouldn't even be needed, but this is Lua after all
            dontShowAgainButton = options.dontShowAgainButton or DEFAULT_DONT_SHOW_AGAIN_BUTTON,
            dontShowAgainButtonCountdownInSec = options.dontShowAgainButtonCountdownInSec or
                DEFAULT_DONT_SHOW_AGAIN_BUTTON_COUNTDOWN,
            displayOnceOnly = options.displayOnceOnly,
            buttons = options.buttons
        }
    })
    instance:InitializeNotificationWindow()
    return instance
end

--- Initializes the notification window and sets up its components
---@return nil
function NotificationManager:InitializeNotificationWindow()
    self.IMGUIwindow = Ext.IMGUI.NewWindow(self.title)
    self.IMGUIwindow.IDContext = self.modUUID .. self.id
    self:ConfigureWindowStyle()
    self:CreateMessageGroup()
    self:CreateDontShowAgainButton()
    self:CreateCustomButtons(self.options.buttons)

    -- Also missing from the SE IMGUI API
    -- self.IMGUIwindow:OnClose(function()
    --     -- or HandleDisplayOnceOnly?
    --     self:Destroy()
    -- end)

    -- On hover or something like that. Can't be done with current API
    -- self:ResetFadeOutTimer()

    self:StartFadeOutTimer()
end

--- Creates custom buttons from the options, if provided, and assigns their callbacks
---@param buttons table<string, function> The button labels and their callbacks
---@return nil
function NotificationManager:CreateCustomButtons(buttons)
    if not buttons then return end
    if table.isEmpty(buttons) then return end

    local hasDontShowAgainButton = self.options.dontShowAgainButton

    local buttonCallbacksGroup = self.IMGUIwindow:AddGroup("button_callbacks_group")

    if hasDontShowAgainButton then
        buttonCallbacksGroup:AddDummy(0, 20)
        buttonCallbacksGroup.SameLine = true
    end

    local isFirstButton = true
    for label, callback in pairs(buttons) do
        local button = self.IMGUIwindow:AddButton(label)

        if isFirstButton and not hasDontShowAgainButton then
            buttonCallbacksGroup:AddDummy(0, 10)
            button.SameLine = false
        else
            button.SameLine = hasDontShowAgainButton ~= nil
        end

        button.OnClick = function()
            callback()
            -- self:Destroy()
        end
        isFirstButton = false
    end
end

--- Cleans up and destroys the IMGUIwindow, also handling the show once parameter
---@return nil
function NotificationManager:Destroy()
    self.IMGUIwindow.Visible = false
    self.IMGUIwindow:SetCollapsed(true)
    self.IMGUIwindow:Destroy()

    self:HandleDisplayOnceOnly()
end

--- Stores the user preference to not show the notification again, if the option is enabled
---@return nil
function NotificationManager:HandleDisplayOnceOnly()
    if self.options.displayOnceOnly == true then
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
    -- self.IMGUIwindow:SetSize({500, 250})
    self.IMGUIwindow.Closeable = false
    self.IMGUIwindow.Visible = true
    self.IMGUIwindow.Open = true

    self.IMGUIwindow:SetColor("TitleBg", NotificationStyles:GetStyleTitleBg(self.notificationSeverity))
    self.IMGUIwindow:SetColor("TitleBgActive", NotificationStyles:GetStyleTitleBg(self.notificationSeverity))
    self.IMGUIwindow:SetColor("TitleBgCollapsed", NotificationStyles:GetStyleTitleBg(self.notificationSeverity))
end

--- Creates a message group within the notification window
---@return nil
function NotificationManager:CreateMessageGroup()
    local messageGroup = self.IMGUIwindow:AddGroup("message_group")
    local borderColor = NotificationStyles:GetStyleBorderColor(self.notificationSeverity)
    local icon = NotificationStyles:GetStyleIcon(self.notificationSeverity)

    local itemIcon = messageGroup:AddImage(icon, { ICON_SIZE, ICON_SIZE })
    if itemIcon then
        itemIcon.SameLine = true
        itemIcon.Border = borderColor
        itemIcon.IDContext = "WarningIcon"
    end

    local messageText = messageGroup:AddText(self.message)
    messageText:SetColor("Text", borderColor)
    messageText.SameLine = true
    -- messageText.TextWrapPos = 0
end

--- Creates a "Don't show again" button in the notification window
---@param countdownTimeInSec number? Optional countdown time for the button
---@return nil
function NotificationManager:CreateDontShowAgainButton(countdownTimeInSec)
    if self.options.dontShowAgainButton ~= true then
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
---@param severity NotificationSeverity The warning severity
---@param title string The title of the warning IMGUIwindow
---@param message string The message to display
---@param options NotificationOptions The options for the warning
---@param modUUID string The UUID of the mod that owns the warning
function NotificationManager:CreateIMGUINotification(id, severity, title, message, options, modUUID)
    if Ext.IsServer() then
        -- TODO: Ext.Net.PostMessageToClient
        return
    end

    if NotificationPreferences:ShouldShowNotification(id, modUUID) then
        return NotificationManager:new(id, severity, title, message, options, modUUID)
    end
end

function NotificationManager:InjectNotificationManagerToModTable(modUUID)
    if Ext.IsServer() then return end
    if modUUID == ModuleUUID then return end

    MCMPrint(2, "Injecting NotificationManager to mod table for modUUID: " .. modUUID)

    local modTableName = ModUUIDToModTableName[modUUID]
    MCMPrint(2, "Mod table name: " .. modTableName)
    local modTable = Mods[modTableName]
    if not modTable then
        MCMWarn(2, "Mod table not found for modUUID: " .. modUUID)
        return
    end

    if modTable.NotificationManager then
        MCMPrint(1,
            "NotificationManager already exists in mod table for modUUID: " ..
            modUUID .. ". Skipping metatable injection.")
        return
    end

    modTable.NotificationManager = self:CreateNotificationFunctions(modUUID)
    modTable.NotificationManager.NotificationOptions = NotificationManager:GetAvailableNotificationOptions()

    MCMSuccess(2, "Successfully injected NotificationManager to mod table for modUUID: " .. modUUID)
end

function NotificationManager:CreateNotificationFunctions(modUUID)
    return {
        --- Displays a warning message to the user
        ---@param id string The unique identifier for the notification
        ---@param title string The title of the warning IMGUIwindow
        ---@param message string The message to display
        ---@param options NotificationOptions The options for the warning
        ---@return function
        ShowInfo = function(id, title, message, options)
            NotificationManager:CreateIMGUINotification(id, 'info', title, message, options, modUUID)
        end,
        ---@param id string The unique identifier for the notification
        ---@param title string The title of the warning IMGUIwindow
        ---@param message string The message to display
        ---@param options NotificationOptions The options for the warning
        ---@return function
        ShowSuccess = function(id, title, message, options)
            NotificationManager:CreateIMGUINotification(id, 'success', title, message, options, modUUID)
        end,
        ---@param id string The unique identifier for the notification
        ---@param title string The title of the warning IMGUIwindow
        ---@param message string The message to display
        ---@param options NotificationOptions The options for the warning
        ---@return function
        ShowWarning = function(id, title, message, options)
            NotificationManager:CreateIMGUINotification(id, 'warning', title, message, options, modUUID)
        end,
        ---@param id string The unique identifier for the notification
        ---@param title string The title of the warning IMGUIwindow
        ---@param message string The message to display
        ---@param options NotificationOptions The options for the warning
        ---@return function
        ShowError = function(id, title, message, options)
            NotificationManager:CreateIMGUINotification(id, 'error', title, message, options, modUUID)
        end
    }
end
