---@class EventButtonWidgetState
---@field Group ExtuiGroup
---@field Setting BlueprintSetting
---@field CooldownGroup ExtuiGroup|nil
---@field ModUUID string
---@field Button (ExtuiButton|ExtuiImageButton)|nil
---@field ButtonCallback function|nil

---@class EventButtonIMGUIWidget: IMGUIWidget
---@field FEEDBACK_TYPE table<string, string>
---@field FEEDBACK_COLORS table<string, vec4>
---@field Widget EventButtonWidgetState
---@field _actionSubject table|nil
---@field _actionSubscription Subscription|nil
---@field _registrySubscription Subscription|nil
---@field _actionFeedbackLabel ExtuiText|nil
---@field _feedbackTooltip ExtuiStyledRenderable|nil
---@field _cooldownTimer unknown
---@field _cooldownEndTime number
---@field _isCooldownActive boolean
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

-- Rx subject for callback events; Observer lets a widget own its registry subscription before replay
local RX = {
    Subject = Ext.Require("Lib/reactivex/subjects/subject.lua"),
    Observer = Ext.Require("Lib/reactivex/observer.lua")
}

local function resolveConfirmText(handle, fallback, defaultHandle, defaultText)
    local resolved = VCString:ResolveBlueprintText(handle, fallback)
    if resolved ~= nil and resolved ~= "" then
        return resolved
    end
    local translated = Ext.Loca.GetTranslatedString(defaultHandle)
    if translated ~= nil and translated ~= "" then
        return translated
    end
    return defaultText
end

---@param setting? BlueprintSetting
function EventButtonIMGUIWidget:HasLabel(setting)
    if not setting then
        setting = self.Widget.Setting
    end
    local options = setting:GetOptions() or {}
    return type(options.Label) == "string" and options.Label ~= ""
end

---@param setting? BlueprintSetting
function EventButtonIMGUIWidget:HasIcon(setting)
    if not setting then
        setting = self.Widget.Setting
    end
    local options = setting:GetOptions() or {}
    return options.Icon and type(options.Icon.Name) == "string" and options.Icon.Name ~= ""
end

---@param setting? BlueprintSetting
function EventButtonIMGUIWidget:GetButtonLabel(setting)
    if not setting then
        setting = self.Widget.Setting
    end
    local options = setting:GetOptions() or {}
    local handles = setting:GetHandles() or {}

    local hasLabel = self:HasLabel(setting)
    local labelHandle = handles.EventButtonHandles and handles.EventButtonHandles.LabelHandle
    local label = VCString:ResolveBlueprintText(labelHandle, hasLabel and options.Label or nil)
    if label ~= nil and label ~= "" then
        return label
    end

    -- Fallback label is the localized name or the setting ID if localization is missing
    local fallbackLabel = setting:GetLocaName()
    if fallbackLabel == nil or fallbackLabel == "" then
        fallbackLabel = setting:GetId()
    end

    return fallbackLabel
end

--- Creates the configured image button, cleaning up a button whose icon cannot be used
---@param container ExtuiGroup
---@param label string
---@param icon table Options.Icon of the setting
---@param settingId string
---@return ExtuiImageButton|nil button nil when the caller must use a text button
local function createImageButton(container, label, icon, settingId)
    local button, isUsable

    -- AddImageButton throws on an invalid size, before it creates a child.
    local success, err = pcall(function()
        local iconSize = IMGUIWidget:GetIconSizes(2)
        if icon.Size then
            iconSize = { icon.Size.Width, icon.Size.Height }
        end

        button = container:AddImageButton(label, icon.Name, iconSize)
        isUsable = button.Image and button.Image.Icon ~= ""
    end)
    if not success then
        MCMWarn(0, "Failed to load icon for event_button '%s': %s", settingId, err)
    end

    if isUsable then return button end
    if not button then return nil end

    button:Destroy()
    return nil
end

function EventButtonIMGUIWidget:CreateButton()
    local buttonLabel = self:GetButtonLabel()
    local setting = self.Widget.Setting
    local options = setting:GetOptions() or {}
    local useIcon = options.Icon and options.Icon.Name and options.Icon.Name ~= ""
    local buttonContainer = self.Widget.Group

    self.Widget.Button = useIcon and createImageButton(buttonContainer, buttonLabel, options.Icon, setting:GetId())
        or buttonContainer:AddButton(buttonLabel)

    self.Widget.CooldownGroup = buttonContainer:AddGroup("CooldownGroup_" .. setting:GetId())
end

---@param group ExtuiGroup
---@param setting BlueprintSetting
---@param currentValue MCMSettingValue
---@param modUUID string
---@return EventButtonIMGUIWidget
function EventButtonIMGUIWidget:new(group, setting, currentValue, modUUID)
    local instance = setmetatable({}, { __index = EventButtonIMGUIWidget })
    ---@cast instance EventButtonIMGUIWidget

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
        title = resolveConfirmText(cdHandles.TitleHandle, confirmOptions.Title,
            "h652b98e111884533a0ec00fd94ecc386f717", "Confirm action")
        message = resolveConfirmText(cdHandles.MessageHandle, confirmOptions.Message,
            "h6cea07ecefe545ddaf13f4259fa75a6b2400", "Are you sure you want to proceed?")
        okLabel = resolveConfirmText(cdHandles.ConfirmTextHandle, confirmOptions.ConfirmText,
            "hf03356ba46684764b32d26ff28d3e709af5a", "OK")
        cancelLabel = resolveConfirmText(cdHandles.CancelTextHandle, confirmOptions.CancelText,
            "he43ef9b250584bc2840b8b291c73e4b53cb4", "Cancel")

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
            MCMError(0, "Error executing callback for event_button '%s': %s", settingId, err)
        end)

        -- Permanent disable when Cooldown == -1 (disable until reload/reset)
        local cooldown = self:GetCooldown()
        if cooldown == -1 then
            self:DisableButton(self.Widget.Button,
                Ext.Loca.GetTranslatedString("h7e3aa28155fe43919d388881ea27a45d0a6b") or
                "Action disabled until reload/reset")
        end
    else
        if callbackEntry then
            MCMDebug(1, "No callback registered for event_button '%s'", settingId)
        else
            MCMDebug(1, "No registry entry found for event_button '%s'", settingId)
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

--- Disables the button and adds a tooltip
---@param button ExtuiButton|ExtuiImageButton The button to disable
---@param tooltipText string The tooltip text to add
function EventButtonIMGUIWidget:DisableButton(button, tooltipText)
    button.Disabled = true
    self:ApplyDisabledStyle(button)
    self._feedbackTooltip = IMGUIHelpers.AddTooltip(button, tooltipText, self.Widget.ModUUID)
end

--- Enables the button and removes any tooltip
---@param button ExtuiButton|ExtuiImageButton The button to enable
function EventButtonIMGUIWidget:EnableButton(button)
    button.Disabled = false
    if button.SetColor then
        button:SetColor("Text", UIStyle.Colors.Text)
    end
    if self._feedbackTooltip then
        self._feedbackTooltip:Destroy()
        self._feedbackTooltip = nil
    end
end

function EventButtonIMGUIWidget:RegisterCallbackSub()
    -- Subscribe to registry updates so we know when a callback becomes available or is removed.
    if self._registrySubscription then return end

    local subject = EventButtonRegistry.GetSubject()
    self:UpdateButtonState(subject:GetValue())
    local initialReplay = true
    local observer = RX.Observer.Create(function(newRegistry)
        if initialReplay then
            initialReplay = false
            return
        end
        self:UpdateButtonState(newRegistry)
    end)
    self._registrySubscription = observer
    subject:Subscribe(observer)
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
        EventButtonRegistry.RemoveWidget(self.Widget.ModUUID, self.Widget.Setting:GetId(), self)
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
        local label = self.Widget.CooldownGroup:AddText(VCString:ResolveBlueprintText(
            "hbaeea4f4db8b46ed98f47a36a38cbe72c463", "Action executed!") --[[@as string]])
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
        ---@cast button ExtuiButton|ExtuiImageButton
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
    MCMDebug(3, "Updating feedback for %s:%s - %s", self.Widget.ModUUID, self.Widget.Setting:GetId(), message)

    -- Clear previous feedback if any
    if self._actionFeedbackLabel then
        self._actionFeedbackLabel:Destroy()
        self._actionFeedbackLabel = nil
        MCMDebug(3, "Cleared previous feedback for %s:%s", self.Widget.ModUUID, self.Widget.Setting:GetId())
    end

    -- Create and display the feedback label
    local label = self.Widget.CooldownGroup:AddText(message)
    label.SameLine = false

    -- Set color based on feedback type
    feedbackType = feedbackType or self.FEEDBACK_TYPE.INFO
    if not self.FEEDBACK_COLORS[feedbackType] then
        MCMWarn(1, "Unknown feedback type: %s. Defaulting to 'info'.", feedbackType)
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
