---@class EventButtonIMGUIWidget: IMGUIWidget
EventButtonIMGUIWidget = _Class:Create("EventButtonIMGUIWidget", IMGUIWidget)

function EventButtonIMGUIWidget:new(group, setting, currentValue, modUUID)
    local instance = setmetatable({}, { __index = EventButtonIMGUIWidget })

    instance.Widget = {
        Group = group,
        Setting = setting,
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
    local buttonContainer = group:AddGroup()
    buttonContainer.IDContext = modUUID .. "_" .. setting:GetId() .. "_EventButtonContainer"
    buttonContainer.Sameline = true

    -- Get button options from setting
    local options = setting:GetOptions() or {}
    local useIcon = options.Icon and options.Icon ~= ""
    local confirmOptions = options.ConfirmDialog

    -- Create either an image button or a regular button
    if useIcon then
        local success, button = xpcall(function()
            local btn = buttonContainer:AddImageButton(setting:GetLocaName(), options.Icon)
            return btn
        end, function(err)
            -- Fallback to regular button if icon fails to load
            MCMWarn(0, "Failed to load icon for event_button '" .. setting:GetId() .. "': " .. tostring(err))
            return buttonContainer:AddButton(setting:GetLocaName())
        end)

        self.Widget.Button = success and button or nil

        -- If xpcall failed but didn't return a button, create a regular button
        if not self.Widget.Button then
            self.Widget.Button = buttonContainer:AddButton(setting:GetLocaName())
        end
    else
        -- Create a regular button
        self.Widget.Button = buttonContainer:AddButton(setting:GetLocaName())
    end

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
end

function EventButtonIMGUIWidget:HandleButtonClick()
    local setting = self.Widget.Setting
    local options = setting:GetOptions() or {}
    local confirmOptions = options.ConfirmDialog

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

        -- Show confirmation dialog
        local dialog = MessageBox:Create(title, message, MessageBoxMode.OkCancel, self.Widget.ModUUID,
            self.Widget.ModUUID .. "_" .. setting:GetId() .. "_Confirm")
        dialog:SetOkCallback(function()
            self:TriggerCallback()
        end)
        dialog:SetCancelCallback(function()
            -- Do nothing on cancel
        end)
        dialog:Show(self.Widget.Group)
    else
        -- No confirmation needed, trigger callback immediately
        self:TriggerCallback()
    end
end

function EventButtonIMGUIWidget:TriggerCallback()
    -- Retrieve and execute the callback registered for this event button
    local reg = KeybindingsRegistry.GetRegistry()
    local modUUID = self.Widget.ModUUID
    local settingId = self.Widget.Setting:GetId()

    -- Emit event for the button click - this allows external systems to react
    ModEventManager:Emit(EventChannels.MCM_EVENT_BUTTON_CLICKED, {
        modUUID = modUUID,
        settingId = settingId,
        timestamp = os.time()
    })

    -- Check if a callback has been registered
    if reg[modUUID] and reg[modUUID][settingId] then
        local callbackEntry = reg[modUUID][settingId]
        local callback = callbackEntry.eventButtonCallback

        if type(callback) == "function" then
            -- Execute the callback with error handling
            xpcall(callback, function(err)
                MCMError(0, "Error executing callback for event_button '" .. settingId .. "': " .. tostring(err))
            end)
        else
            MCMDebug(1, "No callback registered for event_button '" .. settingId .. "'")
        end
    else
        MCMDebug(1, "No registry entry found for event_button '" .. settingId .. "'")
    end
end

function EventButtonIMGUIWidget:RegisterCallback()
    -- Callbacks are registered via the MCMAPI in a separate call
end

function EventButtonIMGUIWidget:UpdateCurrentValue(value)
    -- Event buttons don't have a value to update, they only execute callbacks
end

function EventButtonIMGUIWidget:Destroy()
    if self.Widget.Group then
        self.Widget.Group:Destroy()
    end
end

return EventButtonIMGUIWidget
