---@class IMGUIWidget
IMGUIWidget = _Class:Create("IMGUIWidget", nil, {})

function IMGUIWidget:new()
    error(
        "This is an abstract class and cannot be instantiated directly. IMGUIWidget:New() must be overridden in a derived class")
end

function IMGUIWidget:Create(group, setting, initialValue, modGUID, widgetClass)
    local widgetName = Ext.Loca.GetTranslatedString(setting.Handles.NameHandle)
    if widgetName == nil or widgetName == "" then
        widgetName = setting.Name
    end

    local widget = widgetClass:CreateWidget(group, widgetName, setting, initialValue, modGUID)
    self:InitializeWidget(widget, setting)
    return widget
end

function IMGUIWidget:CreateWidget(group, widgetName, setting, initialValue, modGUID)
    error("IMGUIWidget:CreateWidget must be overridden in a derived class")
end

function IMGUIWidget:InitializeWidget(widget, setting)
    -- widget:AddText(setting:GetDescription())
    self:SetupTooltip(widget, setting)
end

function IMGUIWidget:SetupTooltip(widget, setting)
    if not setting.Tooltip then
        return
    end

    if widget.Tooltip then
        local tooltip = widget:Tooltip()
        tooltip:AddText(setting.Tooltip)
    end
end
