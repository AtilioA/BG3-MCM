-- This became a factory of sorts cause OOP in Lua is a mess

---@class IMGUIWidget
---@field Widget any The actual IMGUI widget object (e.g. SliderInt, Checkbox, etc.)
IMGUIWidget = _Class:Create("IMGUIWidget", nil, {
    Widget = nil
})

function IMGUIWidget:new()
    error(
        "This is an abstract class and cannot be instantiated directly. IMGUIWidget:New() must be overridden in a derived class")
end

function IMGUIWidget:Create(group, setting, initialValue, modGUID, widgetClass)
    local widgetName = Ext.Loca.GetTranslatedString(setting.Handles.NameHandle)
    if widgetName == nil or widgetName == "" then
        widgetName = setting.Name
    end

    local widget = widgetClass:new(group, widgetName, setting, initialValue, modGUID)
    widget.Widget.IDContext = setting.Id
    self:AddResetButton(group, setting, modGUID)
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

function IMGUIWidget:AddResetButton(group, setting, modGUID)
    -- TODO: refactor this to use popup with MouseButtonRight? I don't know how to do that
    local resetButton = group:AddButton("«")
    resetButton.IDContext = "ResetButton_" .. setting.Id
    resetButton:Tooltip():AddText("Reset to default")
    resetButton.OnClick = function()
        IMGUIAPI:ResetConfigValue(setting.Id, modGUID)
    end
    resetButton.SameLine = true
end

function IMGUIWidget:SetupTooltip(widget, setting)
    if not setting.Tooltip then
        return
    end

    if widget.Tooltip then
        local tooltip = widget:Tooltip()
        local tooltipText = setting.Tooltip
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
---@param setting SchemaSetting
---@return nil
function IMGUIWidget:SetupDescription(widget, group, setting)
    if not setting.Description then
        return
    end

    if not widget then
        return
    end

    local descriptionText = setting.Description
    local translatedDescription = Ext.Loca.GetTranslatedString(setting.Handles.DescriptionHandle)
    if translatedDescription ~= nil and translatedDescription ~= "" then
        descriptionText = translatedDescription
    end

    local addedDescription = group:AddText(descriptionText)
    addedDescription:SetColor("Text", Color.normalized_rgba(255, 255, 255, 0.67))
    group:AddDummy(0, 5)
end
