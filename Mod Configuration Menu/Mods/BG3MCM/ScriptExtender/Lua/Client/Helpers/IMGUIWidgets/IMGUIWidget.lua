-- This became a factory of sorts cause OOP in Lua is a mess
-- TODO: ADD modUUID TO ALL IDCONTEXTS SINCE THEY MIGHT NOT BE UNIQUE ACROSS DIFFERENT MODS

---@class IMGUIWidget
---@field Widget any The actual IMGUI widget object (e.g. SliderInt, Checkbox, etc.)
IMGUIWidget = _Class:Create("IMGUIWidget", nil, {
    Widget = nil
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
---@return vec2 - A table containing the icon sizes, e.g. { 32, 32 }
function IMGUIWidget:GetIconSizes()
    local viewportSize = Ext.IMGUI.GetViewportSize()
    local iconSize = self:EstimateIconSize(viewportSize[2])
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

    if widget.AddResetButton then
        widget:AddResetButton(group, setting, modUUID)
    else
        self:AddResetButton(group, setting, modUUID)
    end

    self:InitializeWidget(widget, group, setting)

    return widget
end

function IMGUIWidget:UpdateCurrentValue(value)
    error("IMGUIWidget:UpdateCurrentValue must be overridden in a derived class")
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
    local resetButton = group:AddImageButton("[Reset]", "ico_reset_d", IMGUIWidget:GetIconSizes())
    if not resetButton.Image or resetButton.Image.Icon == "" then
        resetButton:Destroy()
        resetButton = group:AddButton("[Reset]")
    end
    resetButton.IDContext = modUUID .. "_" .. "ResetButton_" .. setting:GetId()
    MCMRendering:AddTooltip(resetButton, Ext.Loca.GetTranslatedString("h132d4b2d4cd044c8a3956a77f7e3499d0737"),
        modUUID .. "_" .. "ResetButton_" .. setting:GetId() .. "_TOOLTIP")
    resetButton.OnClick = function()
        IMGUIAPI:ResetSettingValue(setting:GetId(), modUUID)
    end
    resetButton.SameLine = true
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
