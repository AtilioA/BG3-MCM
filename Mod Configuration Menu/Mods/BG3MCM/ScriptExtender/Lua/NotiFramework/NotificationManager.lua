---@alias NotificationLevel
---| 'info'
---| 'success'
---| 'warning'
---| 'error'

---@class NotificationManager: nil
NotificationManager = _Class:Create("NotificationManager", nil)

---@class NotificationManager
---@field window any
---@field id string
---@field notificationLevel NotificationLevel
---@field message string
---@field title string
NotificationManager = _Class:Create("NotificationManager", nil, {
    window = nil,
    notificationLevel = 'warning', -- Default to 'warning'
    message = "",
    title = "Warning"
})

--- Creates a new warning window
---@param id string The unique identifier for the warning window
---@param level NotificationLevel The warning level
---@param title string The title of the warning window
---@param message string The message to display in the window
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
    self.window = Ext.IMGUI.NewWindow(self.title)
    self:ConfigureWindowStyle()
    self:CreateMessageGroup()
    self:CreateDontShowButton()
end

function NotificationManager:ConfigureWindowStyle()
    self.window:SetStyle("Alpha", 1.0)
    self.window:SetColor("TitleBgActive", Color.NormalizedRGBA(255, 10, 10, 1))
    self.window:SetColor("TitleBg", Color.NormalizedRGBA(255, 38, 38, 0.78))
    self.window:SetColor("WindowBg", Color.NormalizedRGBA(18, 18, 18, 1))
    self.window:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 1))
    self.window.AlwaysAutoResize = true
    self.window.Closeable = false
    self.window.Visible = true
    self.window.Open = true
end

function NotificationManager:CreateMessageGroup()
    local messageGroup = self.window:AddGroup("message_group")
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

function NotificationManager:GetIconAndBorderColor()
    local borderColor = Color.HEXToRGBA("#FF2222")
    local icon = "ico_warning_yellow"
    if self.notificationLevel == 'warning' then
        icon = "ico_exclamation_01"
    elseif self.notificationLevel == 'error' then
        borderColor = Color.HEXToRGBA("#FF9922")
        icon = "ico_exclamation_02"
    elseif self.notificationLevel == 'info' then
        icon = "ico_info"
        borderColor = Color.HEXToRGBA("#22CCFF")
    elseif self.notificationLevel == 'success' then
        icon = "ico_success"
        borderColor = Color.HEXToRGBA("#22FF22")
    end
    return borderColor, icon
end

function NotificationManager:CreateDontShowButton()
    local messageGroup = self.window:GetGroup("message_group")
    messageGroup:AddDummy(0, 10)
    local countdown = 5
    local dontShowButton = self.window:AddButton("Don't show this again (" .. countdown .. ")")
    dontShowButton.OnClick = function()
        -- Store the preference in JSON using NotificationPreferences
        MCMDebug(1, "Saving user preference to suppress notification: " .. self.id .. ".")
        NotificationPreferences:StoreUserDontShowPreference(self.id)
        self.window.Visible = false
        self.window:SetCollapsed(true)
        self.window:Destroy()
    end
    dontShowButton.SameLine = false
    dontShowButton.Disabled = true

    -- Update the button label each second as a countdown
    VCTimer:CallWithInterval(function()
        countdown = countdown - 1
        dontShowButton.Label = "Don't show this again (" .. countdown .. ")"
        if countdown <= 0 then
            dontShowButton.Disabled = false
            dontShowButton.Label = "Don't show this again"
            self.window.Closeable = true
        end
    end, 1000, 5000)
end

--- Displays a warning message to the user
---@param level NotificationLevel The warning level
---@param title string The title of the warning window
---@param message string The message to display
function NotificationManager:CreateIMGUIWarning(id, level, title, message)
    if Ext.IsClient() and NotificationPreferences:ShouldShowNotification(id) then
        return NotificationManager:new(id, level, title, message)
    end
end
