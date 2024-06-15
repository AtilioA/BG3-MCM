-- This became a factory of sorts cause OOP in Lua is a mess
-- TODO: ADD MODGUID TO ALL IDCONTEXTS SINCE THEY MIGHT NOT BE UNIQUE ACROSS DIFFERENT MODS

---@class IMGUIWidget
---@field Widget any The actual IMGUI widget object (e.g. SliderInt, Checkbox, etc.)
IMGUIWidget = _Class:Create("IMGUIWidget", nil, {
    Widget = nil
})

function IMGUIWidget:new()
    error(
        "This is an abstract class and cannot be instantiated directly. IMGUIWidget:New() must be overridden in a derived class")
end

-- TODO: add this annotation to all IMGUIWidget subclasses
--- Create a new IMGUI widget
---@param group any The IMGUI group to add the widget to
---@param setting BlueprintSetting The Setting object that this widget will be responsible for
---@param initialValue any The initial value of the widget
---@param modGUID string The GUID of the mod that owns this widget
---@param widgetClass any The class of the widget to create
function IMGUIWidget:Create(group, setting, initialValue, modGUID, widgetClass)
    local widgetName = setting:GetLocaName()
    if widgetName == nil or widgetName == "" then
        widgetName = setting:GetId()
    end

    group:AddText(widgetName)
    local widget = widgetClass:new(group, setting, initialValue, modGUID)
    widget.Widget.IDContext = modGUID .. "_" .. setting:GetId()

    if widget.AddResetButton then
        widget:AddResetButton(group, setting, modGUID)
    else
        self:AddResetButton(group, setting, modGUID)
    end

    self:InitializeWidget(widget.Widget, group, setting)

    group:AddDummy(0, 2)
    return widget
end

function IMGUIWidget:UpdateCurrentValue(value)
    error("IMGUIWidget:UpdateCurrentValue must be overridden in a derived class")
end

function IMGUIWidget:InitializeWidget(widget, group, setting)
    -- widget:AddText(setting:GetDescription())
    self:SetupTooltip(widget, setting)
    self:SetupDescription(widget, group, setting)
end

--- Add a reset button to the widget
---@param group any The IMGUI group to add the button to
---@param setting BlueprintSetting The Setting object that this widget will be responsible for
---@param modGUID string The GUID of the mod that owns this widget
---@return nil
---@see IMGUIAPI:ResetSettingValue
function IMGUIWidget:AddResetButton(group, setting, modGUID)
    local resetButton = group:AddButton("[Reset]")
    resetButton.IDContext = modGUID .. "_" .. "ResetButton_" .. setting:GetId()
    resetButton:Tooltip():AddText("Reset this setting to its default")
    resetButton.OnClick = function()
        IMGUIAPI:ResetSettingValue(setting:GetId(), modGUID)
    end
    resetButton.SameLine = true
end

function IMGUIWidget:SetupTooltip(widget, setting)
    if setting:GetTooltip() == nil or setting:GetTooltip() == "" then
        return
    end

    if widget.Tooltip then
        local tooltip = widget:Tooltip()
        local tooltipText = setting:GetTooltip()
        local translatedTooltip = Ext.Loca.GetTranslatedString(setting.Handles.TooltipHandle)
        if translatedTooltip ~= nil and translatedTooltip ~= "" then
            tooltipText = translatedTooltip
        end
        tooltip:AddText(tooltipText)
    end
end

--- Add a slightly faded description text below the widget
---@param widget any
---@param group any
---@param setting BlueprintSetting
---@return nil
function IMGUIWidget:SetupDescription(widget, group, setting)
    if not setting:GetDescription() or setting:GetDescription() == "" then
        return
    end

    if not widget then
        return
    end

    local descriptionText = setting:GetDescription()
    local translatedDescription = Ext.Loca.GetTranslatedString(setting:GetHandles().DescriptionHandle)
    if translatedDescription ~= nil and translatedDescription ~= "" then
        descriptionText = MCMUtils.ReplaceBrWithNewlines(translatedDescription)
    end

    local addedDescription = group:AddText(descriptionText)
    addedDescription:SetColor("Text", Color.NormalizedRGBA(255, 255, 255, 0.67))
    group:AddDummy(0, 4)
end
