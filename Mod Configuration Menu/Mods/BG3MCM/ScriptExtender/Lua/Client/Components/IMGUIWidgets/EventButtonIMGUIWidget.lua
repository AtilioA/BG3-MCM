---@class EventButtonIMGUIWidget: IMGUIWidget
EventButtonIMGUIWidget = _Class:Create("EventButtonIMGUIWidget", IMGUIWidget)

function EventButtonIMGUIWidget:GetButtonLabel()
    local setting = self.Widget.Setting
    local options = setting:GetOptions() or {}

    local finalLabel = options.Label
    if not finalLabel or finalLabel == "" then
        finalLabel = setting:GetLocaName()
    end

    return finalLabel
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

    -- Get button options from setting
    local options = setting:GetOptions() or {}
    local useIcon = options.Icon and options.Icon.Name and options.Icon.Name ~= ""
    local confirmOptions = options.ConfirmDialog

    self:CreateButton()

    -- Set button properties
    self.Widget.Button.IDContext = modUUID .. "_" .. setting:GetId() .. "_EventButton"

    -- Add tooltip if available
    local tooltip = setting:GetTooltip()
    if tooltip and tooltip ~= "" then
        MCMRendering:AddTooltip(self.Widget.Button, tooltip, modUUID)
    end

    -- Set the click callback for the button
    self.Widget.Button.OnClick = function()
        self:HandleButtonClick()
    end

    -- Register for callbacks via RX when widget is created
    -- This allows for callbacks to be registered even if the button hasn't been created yet
    self:RegisterCallback()

    -- Initialize button enabled state based on current registry.
    self:UpdateButtonState(EventButtonRegistry.GetRegistry())
end

function EventButtonIMGUIWidget:HandleButtonClick()
    local setting = self.Widget.Setting
    local options = setting:GetOptions() or {}
    local confirmOptions = options.ConfirmDialog
    local cooldown = options.Cooldown

    local wrappedCallback = function()
        local callbackSuccess = self:TriggerCallback()

        -- start cooldown if configured
        if callbackSuccess and cooldown and cooldown > 0 then
            local button = self.Widget.Button
            local countdownText = self.Widget.CooldownGroup:AddText("")
            countdownText.SameLine = false
            -- local cooldownTooltip = MCMRendering:AddTooltip(self.Widget.Button, "This button has a cooldown of " .. cooldown .. " seconds.",
            -- self.Widget.ModUUID)

            local function onTick(el, remaining)
                if not el then
                    MCMError(0, "Cooldown timer ticked on nil element")
                    return true
                end
                el.Disabled = true
                if countdownText then countdownText.Label = "Cooldown: " .. remaining .. "s" end

                return false
            end
            local function onComplete(el)
                if not el then
                    MCMError(0, "Cooldown timer completed on nil element")
                    return
                end
                el.Disabled = false

                if countdownText then countdownText:Destroy() end
                -- -- if cooldownTooltip then cooldownTooltip:Destroy() end
            end
            CooldownHelper:StartCooldown(button, cooldown, onTick, onComplete)
        end
    end

    -- If confirmation dialog is configured, show it before triggering the event
    if confirmOptions then
        -- Handle both new object format and legacy string format
        local title, message

        if type(confirmOptions) == "table" then
            title = confirmOptions.Title or "Confirm"
            message = confirmOptions.Message or "Are you sure you want to proceed?"
        else
            title = "Confirm"
            message = confirmOptions
        end

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

    -- Emit event for the button click - this allows external systems to react
    ModEventManager:Emit(EventChannels.MCM_EVENT_BUTTON_CLICKED, {
        modUUID = modUUID,
        settingId = settingId,
    })

    -- Permanent disable when Cooldown == -1 (disable until reload/reset)
    local options = self.Widget.Setting:GetOptions()
    if options and options.Cooldown == -1 then
        self.Widget.Button.Disabled = true
        MCMRendering:AddTooltip(self.Widget.Button,
            "Action disabled until reload/reset", modUUID)
        return
    end

    -- Check if a callback has been registered
    if reg[modUUID] and reg[modUUID][settingId] then
        local callbackEntry = reg[modUUID][settingId]
        local callback = callbackEntry.eventButtonCallback

        if type(callback) == "function" then
            -- Execute the callback with error handling
            local success = xpcall(callback, function(err)
                MCMError(0, "Error executing callback for event_button '" .. settingId .. "': " .. tostring(err))
            end)
            return success
        else
            MCMDebug(1, "No callback registered for event_button '" .. settingId .. "'")
            return false
        end
    else
        MCMDebug(1, "No registry entry found for event_button '" .. settingId .. "'")
        return false
    end
end

---Updates the visual/interactive state of the button according to whether a callback is registered
---@param registry table|nil A full registry table (may be nil)
function EventButtonIMGUIWidget:UpdateButtonState(registry)
    if not self.Widget or not self.Widget.Button then return end

    registry = registry or {}

    local modUUID = self.Widget.ModUUID
    local settingId = self.Widget.Setting:GetId()

    local callbackExists = registry[modUUID]
        and registry[modUUID][settingId]
        and type(registry[modUUID][settingId].eventButtonCallback) == "function"

    -- Manage enable/disable and tooltip
    if callbackExists then
        self.Widget.Button.Disabled = false
        if self._noCallbackTooltip then
            self._noCallbackTooltip:Destroy()
            self._noCallbackTooltip = nil
        end
    else
        self.Widget.Button.Disabled = true
        if not self._noCallbackTooltip then
            self._noCallbackTooltip = MCMRendering:AddTooltip(
                self.Widget.Button,
                "No callback registered for event_button '" .. settingId .. "'",
                modUUID
            )
        end
    end

    -- Optional: grey out text if disabled for clearer UX
    if self.Widget.Button.SetColor then
        if callbackExists then
            self.Widget.Button:SetColor("Text", Color.HEXToRGBA("#EEEEEE"))
        else
            self.Widget.Button:SetColor("Text", Color.NormalizedRGBA(128, 128, 128, 1))
        end
    end
end

function EventButtonIMGUIWidget:RegisterCallback()
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
    if self._registrySubscription then
        self._registrySubscription:Unsubscribe()
        self._registrySubscription = nil
    end

    if self.Widget and self.Widget.Group then
        self.Widget.Group:Destroy()
    end
end

return EventButtonIMGUIWidget
