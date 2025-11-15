---@class EventButtonIMGUIWidget: IMGUIWidget
EventButtonIMGUIWidget = _Class:Create("EventButtonIMGUIWidget", IMGUIWidget, {
    FEEDBACK_TYPE = {
        SUCCESS = "success",
        ERROR = "error",
        INFO = "info",
        WARNING = "warning"
    },

    FEEDBACK_COLORS = {
        ["success"] = Color.NormalizedRGBA(0, 200, 0, 1),
        ["error"] = Color.NormalizedRGBA(220, 0, 0, 1),
        ["info"] = Color.NormalizedRGBA(0, 120, 215, 1),
        ["warning"] = Color.NormalizedRGBA(255, 165, 0, 1)
    },


    _actionSubject = nil,
    _actionSubscription = nil,
    _registrySubscription = nil,
    _actionFeedbackLabel = nil,
    _cooldownTimer = nil,
    _cooldownEndTime = 0,
    _isCooldownActive = false
})

-- Rx subject for callback events
local RX = { Subject = Ext.Require("Lib/reactivex/subjects/subject.lua") }

-- Gets localized text for a handle, falling back to fallbackText if handle is nil/empty or no translation found
local function localize(handle, fallbackText)
    if type(handle) ~= "string" or handle == "" then return fallbackText end

    local translated = Ext.Loca.GetTranslatedString(handle)
    if translated and translated ~= "" then return translated end

    return fallbackText
end

function EventButtonIMGUIWidget:HasLabel(setting)
    if not setting then
        setting = self.Widget.Setting
    end
    local options = setting:GetOptions() or {}
    return type(options.Label) == "string" and options.Label ~= ""
end

function EventButtonIMGUIWidget:HasIcon(setting)
    if not setting then
        setting = self.Widget.Setting
    end
    local options = setting:GetOptions() or {}
    return options.Icon and type(options.Icon.Name) == "string" and options.Icon.Name ~= ""
end

function EventButtonIMGUIWidget:GetButtonLabel(setting)
    if not setting then
        setting = self.Widget.Setting
    end
    local options = setting:GetOptions() or {}
    local handles = setting:GetHandles() or {}

    local hasLabel = self:HasLabel(setting)
    local hasIcon = self:HasIcon(setting)

    -- Fallback label is the localized name or the setting ID if localization is missing
    local fallbackLabel = setting:GetLocaName()
    if fallbackLabel == nil or fallbackLabel == "" then
        fallbackLabel = setting:GetId()
    end

    -- If no label and no icon, use the setting name/ID directly for the button
    local rawLabel = hasLabel and options.Label or fallbackLabel

    if handles.EventButtonHandles and handles.EventButtonHandles.LabelHandle then
        return localize(handles.EventButtonHandles.LabelHandle, rawLabel)
    end

    return rawLabel
end

function EventButtonIMGUIWidget:CreateButton()
    local buttonLabel = self:GetButtonLabel()
    local setting = self.Widget.Setting
    local options = setting:GetOptions() or {}
    local useIcon = options.Icon and options.Icon.Name and options.Icon.Name ~= ""
    local buttonContainer = self.Widget.Group
    -- Create either an image button or a regular button
    if useIcon then
        local success, button = xpcall(function()
            local iconSize = IMGUIWidget:GetIconSizes(2)
            if options.Icon.Size then
                iconSize = { options.Icon.Size.Width, options.Icon.Size.Height }
            end

            local btn = buttonContainer:AddImageButton(buttonLabel, options.Icon.Name, iconSize)

            if not btn.Image or btn.Image.Icon == "" then
                btn:Destroy()
                btn = buttonContainer:AddButton(buttonLabel)
            end

            return btn
        end, function(err)
            -- Fallback to regular button if icon fails to load
            MCMWarn(0, "Failed to load icon for event_button '" .. setting:GetId() .. "': " .. tostring(err))
            return buttonContainer:AddButton(buttonLabel)
        end)

        self.Widget.Button = success and button or nil

        -- If xpcall failed but didn't return a button, create a regular button
        if not self.Widget.Button then
            self.Widget.Button = buttonContainer:AddButton(buttonLabel)
        end
    else
        -- Create a regular button
        self.Widget.Button = buttonContainer:AddButton(buttonLabel)
    end

    self.Widget.CooldownGroup = buttonContainer:AddGroup("CooldownGroup_" .. setting:GetId())
end

function EventButtonIMGUIWidget:new(group, setting, currentValue, modUUID)
    local instance = setmetatable({}, { __index = EventButtonIMGUIWidget })

    instance.Widget = {
        Group = group,
        Setting = setting,
        CooldownGroup = nil,
        ModUUID = modUUID,
        Button = nil,
        ButtonCallback = nil,
    }

    instance:CreateWidgetElements()

    EventButtonRegistry.SetWidget(modUUID, setting:GetId(), instance)

    return instance
end

function EventButtonIMGUIWidget:CreateWidgetElements()
    local group = self.Widget.Group
    local setting = self.Widget.Setting
    local modUUID = self.Widget.ModUUID

    -- Create a container for the button with proper styling
    local buttonContainer = group:AddGroup("EventButtonGroup_" .. setting:GetId())
    buttonContainer.IDContext = modUUID .. "_" .. setting:GetId() .. "_EventButtonContainer"
    buttonContainer.SameLine = false

    self:CreateButton()

    -- Set button properties
    self.Widget.Button.IDContext = modUUID .. "_" .. setting:GetId() .. "_EventButton"

    -- Set the click callback for the button
    self.Widget.Button.OnClick = function()
        self:HandleButtonClick()
    end

    -- Initialize action handlers
    self:InitActionStream()

    -- Register for callbacks via RX when widget is created
    -- This allows for callbacks to be registered even if the button hasn't been created yet
    self:RegisterCallbackSub()

    -- Initialize button enabled state based on current registry (not necessary since we already subscribe to registry changes)
    -- self:UpdateButtonState(EventButtonRegistry.GetRegistry())
end

function EventButtonIMGUIWidget:GetCooldown()
    local setting = self.Widget.Setting
    local options = setting:GetOptions() or {}
    return options.Cooldown or 0
end

function EventButtonIMGUIWidget:HandleButtonClick()
    local setting = self.Widget.Setting
    local options = setting:GetOptions() or {}
    local confirmOptions = options.ConfirmDialog

    local wrappedCallback = function()
        local callbackSuccess = self:TriggerCallback()
        local cooldown = self:GetCooldown()
        if self._actionSubject then
            self._actionSubject:OnNext({ success = callbackSuccess, cooldown = cooldown })
        end
    end

    -- If confirmation dialog is configured, show it before triggering the event
    if confirmOptions then
        local title, message, okLabel, cancelLabel
        local settingHandles = setting:GetHandles() or {}
        local cdHandles = {}
        if settingHandles.EventButtonHandles and settingHandles.EventButtonHandles.ConfirmDialogHandles then
            cdHandles = settingHandles.EventButtonHandles.ConfirmDialogHandles
        end
        title = localize(cdHandles.TitleHandle,
            confirmOptions.Title or localize("h652b98e111884533a0ec00fd94ecc386f717", "Confirm action"))
        message = localize(cdHandles.MessageHandle,
            confirmOptions.Message or
            localize("h6cea07ecefe545ddaf13f4259fa75a6b2400", "Are you sure you want to proceed?"))
        okLabel = localize(cdHandles.ConfirmTextHandle,
            confirmOptions.ConfirmText or localize("hf03356ba46684764b32d26ff28d3e709af5a", "OK"))
        cancelLabel = localize(cdHandles.CancelTextHandle,
            confirmOptions.CancelText or localize("he43ef9b250584bc2840b8b291c73e4b53cb4", "Cancel"))

        -- Show confirmation dialog via service
        local dialog = DialogService:Confirm(
            self.Widget.ModUUID,
            setting:GetId() .. "_Confirm",
            self.Widget.Group,
            title,
            message,
            function() wrappedCallback() end,
            function() end
        )

        dialog:SetOkLabel(okLabel)
        dialog:SetCancelLabel(cancelLabel)
        dialog:Show(self.Widget.Group)
    else
        -- No confirmation needed, trigger callback immediately
        wrappedCallback()
    end
end

function EventButtonIMGUIWidget:TriggerCallback()
    -- Retrieve and execute the callback registered for this event button
    local reg = EventButtonRegistry.GetRegistry()
    local modUUID = self.Widget.ModUUID
    local settingId = self.Widget.Setting:GetId()
    local callbackSuccess = false

    -- Emit event for the button click - this allows external systems to react
    ModEventManager:Emit(EventChannels.MCM_EVENT_BUTTON_CLICKED, {
        modUUID = modUUID,
        settingId = settingId,
    })

    local callbackEntry = reg[modUUID] and reg[modUUID][settingId]
    local callback = callbackEntry and callbackEntry.eventButtonCallback

    if type(callback) == "function" then
        -- Execute the callback with error handling
        callbackSuccess = xpcall(callback, function(err)
            MCMError(0, "Error executing callback for event_button '" .. settingId .. "': " .. tostring(err))
        end)

        -- Permanent disable when Cooldown == -1 (disable until reload/reset)
        local cooldown = self:GetCooldown()
        if cooldown == -1 then
            self:DisableButton(self.Widget.Button, "Action disabled until reload/reset")
        end
    else
        if callbackEntry then
            MCMDebug(1, "No callback registered for event_button '" .. settingId .. "'")
        else
            MCMDebug(1, "No registry entry found for event_button '" .. settingId .. "'")
        end
        callbackSuccess = false
    end

    return callbackSuccess
end

---Updates the visual/interactive state of the button according to whether a callback is registered
---@param registry table|nil A full registry table (may be nil)
function EventButtonIMGUIWidget:UpdateButtonState(registry)
    if not self.Widget or not self.Widget.Button then return end

    registry = registry or {}

    local modUUID = self.Widget.ModUUID
    local settingId = self.Widget.Setting:GetId()
    local entry = registry[modUUID] and registry[modUUID][settingId] or {}

    -- If explicitly disabled via API
    if entry.disabled then
        self:DisableButton(self.Widget.Button, entry.disabledTooltip or "a")
        return
    end

    local hasCallback = type(entry.eventButtonCallback) == "function"

    if hasCallback then
        self:EnableButton(self.Widget.Button)
    else
        local msg = VCString:InterpolateLocalizedMessage("hc19226a66ff845e0b3e8ddcae7b251c52d23", settingId)
        self:DisableButton(self.Widget.Button, msg)
    end
end

function EventButtonIMGUIWidget:_ApplyDisabledStyle(button)
    if button.SetColor then
        button:SetColor("Text", Color.NormalizedRGBA(128, 128, 128, 1))
    end
end

function EventButtonIMGUIWidget:_ApplyEnabledStyle(button)
    if button.SetColor then
        button:SetColor("Text", UIStyle.Colors.Text)
    end
end

--- Disables the button and adds a tooltip
---@param button ExtuiButton|ExtuiImageButton The button to disable
---@param tooltipText string The tooltip text to add
function EventButtonIMGUIWidget:DisableButton(button, tooltipText)
    button.Disabled = true
    self:_ApplyDisabledStyle(button)
    -- if self._feedbackTooltip then
    --     self._feedbackTooltip:Destroy()
    -- end
    self._feedbackTooltip = IMGUIHelpers.AddTooltip(button, tooltipText, self.Widget.ModUUID)
end

--- Enables the button and removes any tooltip
---@param button ExtuiButton|ExtuiImageButton The button to enable
function EventButtonIMGUIWidget:EnableButton(button)
    button.Disabled = false
    self:_ApplyEnabledStyle(button)
    if self._feedbackTooltip then
        self._feedbackTooltip:Destroy()
        self._feedbackTooltip = nil
    end
end

function EventButtonIMGUIWidget:RegisterCallbackSub()
    -- Subscribe to registry updates so we know when a callback becomes available or is removed.
    if self._registrySubscription then return end
    local ok, sub = pcall(function()
        return EventButtonRegistry.GetSubject():Subscribe(function(newRegistry)
            self:UpdateButtonState(newRegistry)
        end)
    end)

    if ok and sub then
        self._registrySubscription = sub
    end
end

function EventButtonIMGUIWidget:UpdateCurrentValue(value)
    -- Event buttons don't have a value to update, they only execute callbacks
end

function EventButtonIMGUIWidget:Destroy()
    -- Unsubscribe action event stream
    if self._actionSubscription then
        self._actionSubscription:Unsubscribe()
        self._actionSubscription = nil
    end
    if self._registrySubscription then
        self._registrySubscription:Unsubscribe()
        self._registrySubscription = nil
    end

    -- Unregister the widget from EventButtonRegistry
    if self.Widget and self.Widget.Setting then
        EventButtonRegistry.RemoveWidget(self.Widget.ModUUID, self.Widget.Setting:GetId())
    end

    if self.Widget and self.Widget.Group then
        self.Widget.Group:Destroy()
    end
end

function EventButtonIMGUIWidget:InitActionStream()
    self._actionSubject = RX.Subject.Create()
    self._actionSubscription = self._actionSubject:Subscribe(function(event)
        -- Only do the following if no feedback was set by mod authors
        -- self:_HandleActionFeedback(event)
        self:_HandleActionCooldown(event)
    end)
end

---@private
function EventButtonIMGUIWidget:_HandleActionFeedback(event)
    -- Clear previous press feedback
    if self._actionFeedbackLabel then
        self._actionFeedbackLabel:Destroy()
        self._actionFeedbackLabel = nil
    end
    -- Show success or error feedback
    if event.success then
        -- Needs translation: Action executed feedback
        local label = self.Widget.CooldownGroup:AddText(localize("hbaeea4f4db8b46ed98f47a36a38cbe72c463",
            "Action executed!"))
        label.SameLine = false
        label:SetColor("Text", Color.NormalizedRGBA(0, 255, 0, 1))
        self._actionFeedbackLabel = label
        Ext.Timer.WaitFor(5000, function()
            if self._actionFeedbackLabel then
                self._actionFeedbackLabel:Destroy()
                self._actionFeedbackLabel = nil
            end
        end)
    else
        local author = Ext.Mod.GetMod(self.Widget.ModUUID).Info.Author
        local label = self.Widget.CooldownGroup:AddText(VCString:InterpolateLocalizedMessage(
            "h56d95a2dbb034ce6a8145626d3abf55fg274",
            author))
        label.SameLine = false
        label:SetColor("Text", Color.NormalizedRGBA(255, 0, 0, 1))
        self._actionFeedbackLabel = label
    end
end

---@private
function EventButtonIMGUIWidget:_HandleActionCooldown(event)
    -- Start cooldown if configured
    if event.success and event.cooldown and event.cooldown > 0 then
        local button = self.Widget.Button
        local countdownText = self.Widget.CooldownGroup:AddText("")
        countdownText.SameLine = false
        local function onTick(el, remaining)
            el.Disabled = true
            if countdownText then
                countdownText.Label = VCString:InterpolateLocalizedMessage(
                    "hb31fa6f91735475eb72da548b26a3516af31",
                    remaining) .. Ext.Loca.GetTranslatedString("hcd9314b58f0946be8df07686c2cb9518b95g")
            end
            return false
        end
        local function onComplete(el)
            el.Disabled = false
            if countdownText then countdownText:Destroy() end
        end
        CooldownHelper:StartCooldown(button, event.cooldown, onTick, onComplete)
    end
end

--- Update the feedback label with a message
---@param message string The message to display
---@param feedbackType? string The type of feedback ("success", "error", "info", "warning"). Defaults to "info".
---@param duration? number How long to display the feedback in milliseconds. Defaults to 5000ms.
function EventButtonIMGUIWidget:UpdateFeedback(message, feedbackType, duration)
    if not self.Widget or not self.Widget.Button then return end
    if not message or message == "" then return end
    MCMDebug(3, "Updating feedback for " .. self.Widget.ModUUID .. ":" .. self.Widget.Setting:GetId() .. " - " .. message)

    -- Clear previous feedback if any
    if self._actionFeedbackLabel then
        self._actionFeedbackLabel:Destroy()
        self._actionFeedbackLabel = nil
        MCMDebug(3, "Cleared previous feedback for " .. self.Widget.ModUUID .. ":" .. self.Widget.Setting:GetId())
    end

    -- Create and display the feedback label
    local label = self.Widget.CooldownGroup:AddText(message)
    label.SameLine = false

    -- Set color based on feedback type
    feedbackType = feedbackType or self.FEEDBACK_TYPE.INFO
    if not self.FEEDBACK_COLORS[feedbackType] then
        MCMWarn(1, string.format("Unknown feedback type: %s. Defaulting to 'info'.", tostring(feedbackType)))
        feedbackType = self.FEEDBACK_TYPE.INFO
    end

    local color = self.FEEDBACK_COLORS[feedbackType]
    label:SetColor("Text", color)
    self._actionFeedbackLabel = label

    -- Auto-hide the feedback after duration
    if not duration then duration = ClientGlobals.MCM_EVENT_BUTTON_FEEDBACK_DURATION end
    Ext.Timer.WaitFor(duration, function()
        if self._actionFeedbackLabel == label then
            self._actionFeedbackLabel:Destroy()
            self._actionFeedbackLabel = nil
        end
    end)
end

function EventButtonIMGUIWidget:SetupTooltip()
    local tt = IMGUIWidget:SetupTooltip(self.Widget.Button, self.Widget.Setting)
    if not tt then
        return
    end
end

return EventButtonIMGUIWidget
