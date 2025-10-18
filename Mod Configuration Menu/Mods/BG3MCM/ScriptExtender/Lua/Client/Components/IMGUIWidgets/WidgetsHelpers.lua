WidgetHelpers = {}

--- Create an increment/decrement button for slider widgets
---@param group any The Widget group to add the button to
---@param settingId string The setting ID for unique ID context
---@param increment number The increment value (positive for next, negative for previous)
---@param tooltip string The tooltip text
---@param min number The minimum value for clamping
---@param max number The maximum value for clamping
---@param getCurrentValueCallback function Function to call to get the current widget value
---@param setMCMValueCallback function Function to call to set the MCM setting value
---@return any The created button
function WidgetHelpers.CreateSliderStepButton(group, settingId, increment, tooltip, min, max,
                                              getCurrentValueCallback, setMCMValueCallback)
    local label
    local icon
    if increment < 0 then
        label = " < "
        icon = ClientGlobals.DECREMENT_BUTTON_ICON
    else
        label = " > "
        icon = ClientGlobals.INCREMENT_BUTTON_ICON
    end

    local button = group:AddImageButton(label, icon, IMGUIWidget:GetIconSizes())

    if not button.Image or button.Image.Icon == "" then
        button:Destroy()
        button = group:AddButton(label)
    end

    button.IDContext = (increment < 0 and "PreviousButton_" or "NextButton_") .. settingId
    button.OnClick = function()
        local currentValue = getCurrentValueCallback()
        local newValue = math.max(min, math.min(max, currentValue + increment))
        setMCMValueCallback(newValue)
    end

    if tooltip then
        IMGUIHelpers.AddTooltip(button, tooltip, "ButtonTooltip_" .. settingId)
    end

    return button
end

return WidgetHelpers
