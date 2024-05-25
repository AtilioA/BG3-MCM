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

function IMGUIWidget:Create(group, setting, initialValue, modGUID, widgetClass)
    local widgetName = Ext.Loca.GetTranslatedString(setting.Handles.NameHandle)
    if widgetName == nil or widgetName == "" then
        widgetName = setting.Name
    end

    group:AddText(widgetName)
    local widget = widgetClass:new(group, setting, initialValue, modGUID)
    widget.Widget.IDContext = modGUID .. "_" .. setting.Id
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
    -- TODO: refactor this to use popup with MouseButtonRight? SE's IMGUI doesn't support that yet
    local resetButton = group:AddButton("[Reset]")
    resetButton.IDContext = modGUID .. "_" .. "ResetButton_" .. setting.Id
    resetButton:Tooltip():AddText("Reset this value to the default")
    resetButton.OnClick = function()
        IMGUIAPI:ResetSettingValue(setting.Id, modGUID)
    end
    resetButton.SameLine = true
end

function IMGUIWidget:SetupTooltip(widget, setting)
    if setting.Tooltip == nil or setting.Tooltip == "" then
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
