-- This became a factory of sorts cause OOP in Lua is a mess
-- TODO: ADD modUUID TO ALL IDCONTEXTS SINCE THEY MIGHT NOT BE UNIQUE ACROSS DIFFERENT MODS

---@class IMGUIWidget
---@field Widget any The actual IMGUI widget object (e.g. SliderInt, Checkbox, etc.)
---@field _currentValue any The current value of the widget (for internal use)
---@field _defaultValue any The default value of the widget (for internal use)
---@field _resetButton any The reset button IMGUI object (for internal use)
IMGUIWidget = _Class:Create("IMGUIWidget", nil, {
    Widget = nil,
    _currentValue = nil,
    _defaultValue = nil,
    _resetButton = nil
})

-- Function to estimate icon size based on viewport size
-- This is used to scale the icon size based on the resolution, so that it looks good on all resolutions
-- I don't know if this is the best way to do it. I just made it up.
---@param height integer The height of the viewport
---@return number iconSize The estimated icon size
function IMGUIWidget:EstimateIconSize(height)
    -- Estimate the icon size using this made up formula
    local iconSize = 0.0194 * height + 0.048

    return math.floor(iconSize + 0.5)
end

--- Get the icon sizes for the widget
--- This is used to set the size of the icon for the widget
--- @param multiplier? number The multiplier to apply to the icon size
---@return vec2 - A table containing the icon sizes, e.g. { 32, 32 }
function IMGUIWidget:GetIconSizes(multiplier)
    multiplier = multiplier or 1
    local viewportSize = Ext.IMGUI.GetViewportSize()
    local iconSize = self:EstimateIconSize(viewportSize[2]) * multiplier
    return { iconSize, iconSize }
end

function IMGUIWidget:new()
    error(
        "This is an abstract class and cannot be instantiated directly. IMGUIWidget:New() must be overridden in a derived class")
end

-- TODO: add this annotation to all IMGUIWidget subclasses
--- Create a new IMGUI widget
---@param group any The IMGUI group to add the widget to
---@param setting BlueprintSetting The Setting object that this widget will be responsible for
---@param initialValue any The initial value of the widget
---@param modUUID string The UUID of the mod that owns this widget
---@param widgetClass any The class of the widget to create
function IMGUIWidget:Create(group, setting, initialValue, modUUID, widgetClass)
    local widgetName = setting:GetLocaName()
    if widgetName == nil or widgetName == "" then
        widgetName = setting:GetId()
    end

    local widgetNameText = group:AddText(widgetName)
    widgetNameText.TextWrapPos = 0

    local widget = widgetClass:new(group, setting, initialValue, modUUID)
    widget.Widget.IDContext = modUUID .. "_" .. setting:GetId()

    -- Store essential information for reset functionality
    widget._currentValue = initialValue
    widget._defaultValue = setting:GetDefault()

    -- First, intercept the original UpdateCurrentValue method
    if not widget._originalUpdateCurrentValue then
        widget._originalUpdateCurrentValue = widget.UpdateCurrentValue
        widget.UpdateCurrentValue = function(self, value)
            -- Update internal value tracking
            self._currentValue = value

            -- Call the original method
            self:_originalUpdateCurrentValue(value)

            -- Update reset button visibility
            self:UpdateResetButtonVisibility()
        end
    end

    -- Store a reference to handle OnChange interception after widget is fully created
    widget._needsOnChangeIntercept = true

    -- Add reset button after we've set up the widget
    if widget.AddResetButton then
        widget:AddResetButton(group, setting, modUUID)
    else
        self:AddResetButton(group, setting, modUUID)
    end

    self:InitializeWidget(widget, group, setting)

    -- Now intercept OnChange handlers if needed
    -- We do this after initialization because some widgets might set up their OnChange handlers during initialization
    if widget._needsOnChangeIntercept and widget.Widget then
        local originalOnChange = widget.Widget.OnChange
        if originalOnChange then
            widget.Widget.OnChange = function(value)
                -- Update internal tracking before executing original handler
                local actualValue = self:ExtractValueFromWidgetEvent(widget, value)
                widget._currentValue = actualValue

                -- Call original handler
                originalOnChange(value)

                -- Update visibility after value change
                widget:UpdateResetButtonVisibility()
            end
        end
        widget._needsOnChangeIntercept = nil
    end

    -- Apply initial visibility
    widget:UpdateResetButtonVisibility()

    return widget
end

function IMGUIWidget:UpdateCurrentValue(value)
    error("IMGUIWidget:UpdateCurrentValue must be overridden in a derived class")
end

--- Extract the value from the widget's OnChange event
--- This must be implemented by each widget subclass to properly handle its specific event structure
--- @param value any The value from the OnChange event
--- @return any The extracted value
function IMGUIWidget:GetOnChangeValue(value)
    error("IMGUIWidget:GetOnChangeValue must be overridden in a derived class")
end

--- Extract the actual value from a widget event
--- Different widget types have different event structures, so this attempts to get the value in a generic way
--- @param widget any The widget instance
--- @param eventValue any The value from the OnChange event
--- @return any The extracted value
function IMGUIWidget:ExtractValueFromWidgetEvent(widget, eventValue)
    -- Use the widget's specific GetOnChangeValue if available
    if widget.GetOnChangeValue then
        local success, result = xpcall(function()
            return widget:GetOnChangeValue(eventValue)
        end, debug.traceback)

        if success then
            return result
        end
    end

    -- Fallback to returning the entire event value if the specific method failed or doesn't exist
    return eventValue
end

--- Updates the visibility of the reset button based on whether current value equals default value
--- This method doesn't require any parameters as it uses the widget's internal state
function IMGUIWidget:UpdateResetButtonVisibility()
    if not self._resetButton then return end

    -- Compare current value with default value
    local isAtDefaultValue = self:IsValueEqualToDefault(self._currentValue, self._defaultValue)

    -- Update visibility
    self._resetButton.Visible = not isAtDefaultValue
end

--- Compares two values to check if they are equal, handling different types appropriately
---@param currentValue any The current value
---@param defaultValue any The default value
---@return boolean True if the values are equal
function IMGUIWidget:IsValueEqualToDefault(currentValue, defaultValue)
    if currentValue == nil or defaultValue == nil then
        return currentValue == defaultValue
    end

    -- Handle different types
    local valueType = type(currentValue)

    if valueType == "table" then
        -- For tables, compare all values
        if type(defaultValue) ~= "table" then
            return false
        end

        -- Check if all table keys/values match
        for k, v in pairs(currentValue) do
            if defaultValue[k] == nil or not self:IsValueEqualToDefault(v, defaultValue[k]) then
                return false
            end
        end

        -- Check for extra keys in defaultValue
        for k, _ in pairs(defaultValue) do
            if currentValue[k] == nil then
                return false
            end
        end

        return true
    else
        -- For simple types, just compare directly
        return currentValue == defaultValue
    end
end

function IMGUIWidget:InitializeWidget(widget, group, setting)
    if widget and widget.SetupTooltip then
        widget:SetupTooltip(widget.Widget, setting)
    else
        self:SetupTooltip(widget.Widget, setting)
    end

    self:SetupDescription(widget.Widget, group, setting)
end

--- Add a reset button to the widget
---@param group any The IMGUI group to add the button to
---@param setting BlueprintSetting The Setting object that this widget will be responsible for
---@param modUUID string The UUID of the mod that owns this widget
---@return nil
---@see IMGUIAPI:ResetSettingValue
function IMGUIWidget:AddResetButton(group, setting, modUUID)
    -- Create the reset button
    local resetButton = group:AddImageButton("[Reset]", ClientGlobals.RESET_SETTING_BUTTON_ICON,
        IMGUIWidget:GetIconSizes())
    if not resetButton.Image or resetButton.Image.Icon == "" then
        resetButton:Destroy()
        resetButton = group:AddButton("[Reset]")
    end

    resetButton.IDContext = modUUID .. "_" .. "ResetButton_" .. setting:GetId()

    local tooltipText = VCString:InterpolateLocalizedMessage("h132d4b2d4cd044c8a3956a77f7e3499d0737", self._defaultValue)

    MCMRendering:AddTooltip(resetButton, tooltipText,
        modUUID .. "_" .. "ResetButton_" .. setting:GetId() .. "_TOOLTIP")

    -- Override the OnClick handler to update internal values after reset
    resetButton.OnClick = function()
        IMGUIAPI:ResetSettingValue(setting:GetId(), modUUID)

        -- It's a reset button, so we'll soon have default == current
        -- Let's hook into the event system to update our tracking when the reset completes
        ModEventManager:Subscribe(EventChannels.MCM_SETTING_SAVED, function(data)
            if data.modUUID == modUUID and data.settingId == setting:GetId() then
                -- Update our internal value tracking
                self._currentValue = data.value

                -- Update visibility
                self:UpdateResetButtonVisibility()
            end
        end)
    end
    resetButton.SameLine = true

    -- Store the reset button reference
    self._resetButton = resetButton

    -- Initial visibility will be set by the caller in Create()
end

function IMGUIWidget:SetupTooltip(widget, setting)
    if setting:GetTooltip() == nil or setting:GetTooltip() == "" then
        return
    end
    local tooltipText = setting:GetTooltip()
    local translatedTooltip = nil
    if setting.Handles.TooltipHandle ~= nil then
        translatedTooltip = Ext.Loca.GetTranslatedString(setting.Handles.TooltipHandle)
    end
    if translatedTooltip ~= nil and translatedTooltip ~= "" then
        tooltipText = translatedTooltip
    end
    MCMRendering:AddTooltip(widget, tooltipText, setting:GetId() .. "_TOOLTIP")
end

--- Add a slightly faded description text below the widget
---@param widget any
---@param group any
---@param setting BlueprintSetting
---@return nil
function IMGUIWidget:SetupDescription(widget, group, setting)
    if not setting:GetDescription() or setting:GetDescription() == "" then
        MCMDebug(1, "No description found for setting: " .. setting:GetId())
        return
    end

    if not widget then
        MCMWarn(0, "Widget is nil for setting: " .. setting:GetId())
        return
    end

    local descriptionText = setting:GetDescription() or ""

    local descriptionHandle = setting:GetHandles() and setting:GetHandles().DescriptionHandle
    if descriptionHandle and descriptionHandle ~= "" then
        local translatedDescription = Ext.Loca.GetTranslatedString(descriptionHandle)
        if translatedDescription and translatedDescription ~= "" then
            descriptionText = VCString:ReplaceBrWithNewlines(translatedDescription)
        end
    end

    local addedDescription = group:AddText(descriptionText)
    addedDescription.TextWrapPos = 0

    addedDescription.IDContext = group.IDContext .. "_Description"

    addedDescription:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 0.67))
end
