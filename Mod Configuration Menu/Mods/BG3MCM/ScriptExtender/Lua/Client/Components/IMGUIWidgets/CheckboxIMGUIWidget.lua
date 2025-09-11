---@class CheckboxIMGUIWidget: IMGUIWidget
CheckboxIMGUIWidget = _Class:Create("CheckboxIMGUIWidget", IMGUIWidget)

function CheckboxIMGUIWidget:new(group, setting, initialValue, modUUID)
    -- Ensure Widget is an instance-specific property. This is some Lua nonsense that I don't understand. Try designing a better language next time. /hj
    local instance = setmetatable({}, { __index = CheckboxIMGUIWidget })

    instance.UserData = {
        ModUUID = modUUID,
        LabelWidget = nil
    }

    instance.Widget = group:AddCheckbox("", initialValue)
    instance.Widget.OnChange = function(value)
        IMGUIAPI:SetSettingValue(setting.Id, value.Checked, modUUID)
    end
    instance.Widget.SameLine = false

    local opts = setting:GetOptions() or {}
    if opts["InlineTitle"] ~= false then
        instance:_addLabelWidget(group, setting, modUUID)
    end

    return instance
end

--- Adds a title text to the checkbox that can be clicked to toggle the checkbox.
---@param group any
---@param setting BlueprintSetting
---@param modUUID string
function CheckboxIMGUIWidget:_addLabelWidget(group, setting, modUUID)
    local LabelWidget = setting:GetLocaName() or setting:GetId()
    if LabelWidget == "" then return end

    local checkboxLabelWidget = group:AddText(LabelWidget)

    checkboxLabelWidget.OnClick = function()
        IMGUIAPI:SetSettingValue(setting.Id, not self.Widget.Checked, modUUID)
    end

    checkboxLabelWidget.OnHoverEnter = function()
        self.Widget:SetColor("FrameBg", UIStyle.UnofficialColors.BoxHoverColor)
    end

    checkboxLabelWidget.OnHoverLeave = function()
        self.Widget:SetColor("FrameBg", UIStyle.UnofficialColors.BoxColor)
    end

    checkboxLabelWidget.TextWrapPos = 0
    checkboxLabelWidget.SameLine = true

    self.UserData.LabelWidget = checkboxLabelWidget
end

function CheckboxIMGUIWidget:UpdateCurrentValue(value)
    self.Widget.Checked = value
end

function CheckboxIMGUIWidget:GetOnChangeValue(value)
    return value.Checked
end

function CheckboxIMGUIWidget:SetupTooltip(widget, setting)
    IMGUIWidget:SetupTooltip(self.UserData.LabelWidget, setting)
    return IMGUIWidget:SetupTooltip(widget, setting)
end
